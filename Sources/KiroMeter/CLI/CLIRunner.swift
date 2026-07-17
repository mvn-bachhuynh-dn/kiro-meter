import Foundation
import Darwin

/// Result from running a CLI command.
public struct CLIRunResult: Sendable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32
    public let timedOut: Bool

    /// Combined output (stdout + stderr), which is what we parse.
    public var combinedOutput: String {
        [stdout, stderr]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

/// Errors from CLI execution.
public enum CLIRunError: Error, Sendable {
    case executableNotFound
    case timeout
    case processFailed(exitCode: Int32, output: String)
}

/// Runs kiro-cli asynchronously with proper timeout and cancellation support.
///
/// Design notes (see `.kiro/steering/macos-appkit.md` — sleep/wake resilience):
/// - Output is drained with async `readabilityHandler`s into a lock-protected
///   buffer. We NEVER block a Swift cooperative thread on a synchronous
///   `readDataToEndOfFile()`. A child that keeps the pipe write-end open after a
///   sleep/wake cycle used to wedge that read forever, which in turn wedged the
///   enclosing task group (it must drain all child tasks) and left the UI's
///   `isLoading` stuck `true` — a permanent spinner with no way to recover.
/// - We wait for the process via `terminationHandler` (non-blocking) and, on
///   timeout or cancellation, force-kill it so that wait always resolves.
public actor CLIRunner {
    private let executablePath: String
    private let overallTimeout: Duration
    private let idleTimeout: Duration

    public init(
        executablePath: String,
        overallTimeout: Duration = .seconds(20),
        idleTimeout: Duration = .seconds(4)
    ) {
        self.executablePath = executablePath
        self.overallTimeout = overallTimeout
        self.idleTimeout = idleTimeout
    }

    /// Run kiro-cli with the given arguments and capture output.
    public func run(arguments: [String]) async throws -> CLIRunResult {
        try Task.checkCancellation()

        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            throw CLIRunError.executableNotFound
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.environment = ExecutableResolver.enrichedEnvironment()

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Drain both pipes asynchronously so a wedged child can never block a
        // cooperative thread on a synchronous read.
        let outReader = PipeReader(stdoutPipe.fileHandleForReading)
        let errReader = PipeReader(stderrPipe.fileHandleForReading)

        // Start process
        do {
            try process.run()
        } catch {
            outReader.cancel()
            errReader.cancel()
            throw CLIRunError.executableNotFound
        }

        // Wait for exit or timeout, whichever comes first. `onCancel` and the
        // timeout branch both force-kill the process so `waitForExit` always
        // resolves and the task group can drain — no deadlock.
        let timedOut: Bool
        do {
            timedOut = try await withTaskCancellationHandler {
                try await withThrowingTaskGroup(of: Bool.self) { group in
                    group.addTask {
                        await CLIRunner.waitForExit(process)
                        return false
                    }
                    group.addTask {
                        try await Task.sleep(for: self.overallTimeout)
                        return true
                    }
                    let first = try await group.next()!
                    if first {
                        // Timed out: kill so the pending waitForExit task can finish.
                        CLIRunner.killProcessTree(process)
                    }
                    group.cancelAll()
                    return first
                }
            } onCancel: {
                CLIRunner.killProcessTree(process)
            }
        } catch is CancellationError {
            CLIRunner.killProcessTree(process)
            outReader.cancel()
            errReader.cancel()
            throw CancellationError()
        }

        if timedOut {
            outReader.cancel()
            errReader.cancel()
            throw CLIRunError.timeout
        }

        // Success path: process exited on its own. Wait (with a bounded grace)
        // for the pipes to reach EOF so we capture the complete output, then
        // detach the handlers.
        await CLIRunner.drainWithGrace(outReader, errReader, grace: .seconds(2))
        outReader.cancel()
        errReader.cancel()

        let stdout = String(data: outReader.data(), encoding: .utf8) ?? ""
        let stderr = String(data: errReader.data(), encoding: .utf8) ?? ""

        return CLIRunResult(
            stdout: stdout,
            stderr: stderr,
            exitCode: process.terminationStatus,
            timedOut: false
        )
    }

    /// Fetch usage data from kiro-cli.
    /// Tries preferred profile first, falls back to portable profile.
    public func fetchUsage() async throws -> CLIRunResult {
        // Preferred: matches the alias `ku`
        let preferredArgs = ["chat", "--classic", "--no-interactive", "--agent", "bare", "/usage"]

        do {
            let result = try await run(arguments: preferredArgs)
            // If the CLI doesn't support --classic or --agent bare, it may fail
            if result.exitCode == 0 || !result.combinedOutput.isEmpty {
                return result
            }
        } catch CLIRunError.timeout {
            throw CLIRunError.timeout
        } catch {
            // Fall through to portable profile
        }

        // Fallback: portable profile without --classic/--agent
        let fallbackArgs = ["chat", "--no-interactive", "/usage"]
        return try await run(arguments: fallbackArgs)
    }

    // MARK: - Private helpers

    /// Suspends until the process terminates. Non-blocking: relies on
    /// `terminationHandler` rather than `waitUntilExit()`. Safe to call when the
    /// process has already exited.
    private nonisolated static func waitForExit(_ process: Process) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            let resumer = ResumeOnce { cont.resume() }
            process.terminationHandler = { _ in resumer.fire() }
            // Guard against the race where the process exited before the handler
            // was installed (terminationHandler would then never fire).
            if !process.isRunning {
                resumer.fire()
            }
        }
    }

    /// Send SIGTERM then SIGKILL so the process is guaranteed to die and its
    /// `terminationHandler` fires. Idempotent / safe if already dead.
    private nonisolated static func killProcessTree(_ process: Process) {
        guard process.isRunning else { return }
        let pid = process.processIdentifier
        process.terminate()          // SIGTERM (graceful)
        if pid > 0 {
            kill(pid, SIGKILL)       // force — cannot be ignored
        }
    }

    /// Wait for both readers to reach EOF, but no longer than `grace`, so a
    /// lingering grandchild holding the pipe open can't stall the success path.
    private nonisolated static func drainWithGrace(
        _ out: PipeReader,
        _ err: PipeReader,
        grace: Duration
    ) async {
        _ = try? await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                await out.waitForEOF()
                await err.waitForEOF()
            }
            group.addTask {
                try await Task.sleep(for: grace)
            }
            _ = try await group.next()
            // Resume any pending EOF waiters so the group can drain even if EOF
            // never actually arrives.
            out.cancel()
            err.cancel()
            group.cancelAll()
        }
    }
}

/// One-shot resume guard so a `CheckedContinuation` is never resumed twice.
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false
    private let action: @Sendable () -> Void

    init(_ action: @escaping @Sendable () -> Void) {
        self.action = action
    }

    func fire() {
        lock.lock()
        if fired { lock.unlock(); return }
        fired = true
        lock.unlock()
        action()
    }
}

/// Asynchronously drains a `FileHandle` into a lock-protected buffer using a
/// `readabilityHandler`. Never blocks a cooperative thread. Exposes EOF as an
/// awaitable so callers can wait for complete output without risking a hang.
private final class PipeReader: @unchecked Sendable {
    private let lock = NSLock()
    private let handle: FileHandle
    private var buffer = Data()
    private var finished = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(_ handle: FileHandle) {
        self.handle = handle
        handle.readabilityHandler = { [weak self] h in
            guard let self else { return }
            let chunk = h.availableData
            if chunk.isEmpty {
                // EOF: all write-ends closed.
                self.finish(detach: h)
            } else {
                self.lock.lock()
                self.buffer.append(chunk)
                self.lock.unlock()
            }
        }
    }

    /// The bytes captured so far.
    func data() -> Data {
        lock.lock(); defer { lock.unlock() }
        return buffer
    }

    /// Suspends until EOF is reached (or `cancel()` is called).
    func waitForEOF() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            lock.lock()
            if finished {
                lock.unlock()
                cont.resume()
                return
            }
            waiters.append(cont)
            lock.unlock()
        }
    }

    /// Detach the handler and resume any waiters. Idempotent.
    func cancel() {
        finish(detach: handle)
    }

    private func finish(detach handle: FileHandle) {
        lock.lock()
        if finished {
            lock.unlock()
            return
        }
        finished = true
        let pending = waiters
        waiters = []
        lock.unlock()

        handle.readabilityHandler = nil
        for cont in pending {
            cont.resume()
        }
    }
}
