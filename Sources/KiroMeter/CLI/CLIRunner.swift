import Foundation

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

        // Start process
        do {
            try process.run()
        } catch {
            throw CLIRunError.executableNotFound
        }

        // Wait with timeout
        let result: CLIRunResult
        do {
            result = try await withThrowingTaskGroup(of: CLIRunResult.self) { group in
                // Task 1: Wait for process completion
                group.addTask {
                    return await self.waitForProcess(
                        process: process,
                        stdoutPipe: stdoutPipe,
                        stderrPipe: stderrPipe
                    )
                }

                // Task 2: Overall timeout
                group.addTask {
                    try await Task.sleep(for: self.overallTimeout)
                    throw CLIRunError.timeout
                }

                // Return first completed task
                let firstResult = try await group.next()!
                group.cancelAll()

                // Ensure process is terminated if timed out
                if process.isRunning {
                    process.terminate()
                    // Give it a moment to exit cleanly
                    try? await Task.sleep(for: .milliseconds(100))
                    if process.isRunning {
                        process.interrupt()
                    }
                }

                return firstResult
            }
        } catch is CancellationError {
            terminateProcess(process)
            throw CancellationError()
        } catch {
            terminateProcess(process)
            throw error
        }

        return result
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

    // MARK: - Private

    private func waitForProcess(
        process: Process,
        stdoutPipe: Pipe,
        stderrPipe: Pipe
    ) async -> CLIRunResult {
        // Read output in background
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        process.waitUntilExit()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        return CLIRunResult(
            stdout: stdout,
            stderr: stderr,
            exitCode: process.terminationStatus,
            timedOut: false
        )
    }

    private nonisolated func terminateProcess(_ process: Process) {
        if process.isRunning {
            process.terminate()
        }
    }
}
