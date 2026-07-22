import Foundation

/// Service that fetches account identity and privacy settings from kiro-cli.
/// Reuses the same executable resolution and CLI runner infrastructure as UsageService.
public actor AccountService {
    private let resolver: ExecutableResolver
    private var runner: CLIRunner?
    private var resolvedPath: String?

    public init(customExecutablePath: String? = nil) {
        self.resolver = ExecutableResolver(customPath: customExecutablePath)
    }

    /// Fetch account info by running `kiro-cli whoami`.
    public func fetchAccountInfo() async throws -> AccountInfo? {
        let runner = try resolveRunner()

        let result = try await runner.run(arguments: ["whoami"])

        let output = result.combinedOutput
        guard !output.isEmpty else { return nil }

        return AccountParser.parseWhoami(output)
    }

    /// Fetch privacy settings by running `kiro-cli settings list -f json`.
    public func fetchPrivacySettings() async throws -> PrivacySettings? {
        let runner = try resolveRunner()

        let result = try await runner.run(arguments: ["settings", "list", "-f", "json"])

        let output = result.combinedOutput
        guard !output.isEmpty else { return nil }

        return AccountParser.parseSettings(output)
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

    // MARK: - Private

    private func resolveRunner() throws -> CLIRunner {
        if let runner { return runner }

        guard let path = resolver.resolve() else {
            throw AccountServiceError.executableNotFound
        }
        resolvedPath = path
        let newRunner = CLIRunner(executablePath: path)
        runner = newRunner
        return newRunner
    }
}

/// Errors from the account service layer.
public enum AccountServiceError: Error, LocalizedError, Sendable {
    case executableNotFound

    public var errorDescription: String? {
        switch self {
        case .executableNotFound:
            "kiro-cli not found. Install Kiro CLI or set the path in Settings."
        }
    }
}
