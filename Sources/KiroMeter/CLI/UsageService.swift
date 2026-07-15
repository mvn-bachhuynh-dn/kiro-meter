import Foundation

/// Service that fetches and parses Kiro usage data.
/// Orchestrates ExecutableResolver → CLIRunner → UsageParser.
public actor UsageService {
    private let resolver: ExecutableResolver
    private var runner: CLIRunner?
    private var resolvedPath: String?

    public init(customExecutablePath: String? = nil) {
        self.resolver = ExecutableResolver(customPath: customExecutablePath)
    }

    /// Fetch current usage. Resolves executable path lazily.
    public func fetchUsage() async throws -> UsageSnapshot {
        // Resolve executable if not yet done
        if resolvedPath == nil {
            guard let path = resolver.resolve() else {
                throw UsageServiceError.executableNotFound
            }
            resolvedPath = path
            runner = CLIRunner(executablePath: path)
        }

        guard let runner else {
            throw UsageServiceError.executableNotFound
        }

        // Run CLI and get output
        let result: CLIRunResult
        do {
            result = try await runner.fetchUsage()
        } catch CLIRunError.timeout {
            throw UsageServiceError.timeout
        } catch CLIRunError.executableNotFound {
            // Reset cached path since it's no longer valid
            resolvedPath = nil
            self.runner = nil
            throw UsageServiceError.executableNotFound
        } catch {
            throw UsageServiceError.cliFailed(error.localizedDescription)
        }

        // Parse combined output
        let output = result.combinedOutput
        guard !output.isEmpty else {
            throw UsageServiceError.emptyResponse
        }

        do {
            return try UsageParser.parse(output)
        } catch let error as UsageParseError {
            switch error {
            case .emptyOutput:
                throw UsageServiceError.emptyResponse
            case .notLoggedIn:
                throw UsageServiceError.notLoggedIn
            case .backendError(let msg):
                throw UsageServiceError.backendError(msg)
            case .unrecognizedFormat(let msg):
                throw UsageServiceError.parseError(msg)
            }
        }
    }

    /// Get diagnostic info about the resolved executable.
    public func diagnostics() -> (path: String?, version: String?) {
        guard let path = resolvedPath ?? resolver.resolve() else {
            return (nil, nil)
        }
        let version = resolver.detectVersion(at: path)
        return (path, version)
    }

    /// Force re-resolution of executable path (e.g. after settings change).
    public func resetExecutablePath(customPath: String? = nil) {
        resolvedPath = nil
        runner = nil
        if let customPath {
            resolvedPath = customPath
            runner = CLIRunner(executablePath: customPath)
        }
    }
}

/// Errors from the usage service layer.
public enum UsageServiceError: Error, LocalizedError, Sendable {
    case executableNotFound
    case timeout
    case notLoggedIn
    case emptyResponse
    case backendError(String)
    case cliFailed(String)
    case parseError(String)

    public var errorDescription: String? {
        switch self {
        case .executableNotFound:
            "kiro-cli not found. Install Kiro CLI or set the path in Settings."
        case .timeout:
            "Kiro CLI timed out. Please try again."
        case .notLoggedIn:
            "Not logged in to Kiro. Run 'kiro-cli login' in Terminal."
        case .emptyResponse:
            "Kiro CLI returned no data. Please try again."
        case .backendError(let msg):
            msg
        case .cliFailed(let msg):
            "CLI error: \(msg)"
        case .parseError(let msg):
            msg
        }
    }
}
