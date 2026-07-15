import Foundation

/// Resolves the path to `kiro-cli` executable.
/// GUI apps do not inherit shell aliases or full PATH from .zshrc,
/// so we search common installation locations explicitly.
public struct ExecutableResolver: Sendable {
    /// Custom path override (from user settings).
    private let customPath: String?

    public init(customPath: String? = nil) {
        self.customPath = customPath
    }

    /// Resolve the executable path. Returns nil if not found.
    public func resolve() -> String? {
        // 1. Custom path takes highest priority
        if let custom = customPath, isValidExecutable(custom) {
            return custom
        }

        // 2. Search enriched PATH and common locations
        for candidate in searchPaths() {
            if isValidExecutable(candidate) {
                return candidate
            }
        }

        return nil
    }

    /// Verify an executable exists and is runnable.
    public func isValidExecutable(_ path: String) -> Bool {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), !isDir.boolValue else {
            return false
        }
        return fm.isExecutableFile(atPath: path)
    }

    /// Run `kiro-cli --version` and return the version string if successful.
    public func detectVersion(at path: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--version"]
        process.environment = Self.enrichedEnvironment()

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else { return nil }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            // Output like "kiro-cli 1.23.1" or just "1.23.1"
            if output.hasPrefix("kiro-cli ") {
                return String(output.dropFirst("kiro-cli ".count))
            }
            return output.isEmpty ? nil : output
        } catch {
            return nil
        }
    }

    // MARK: - Search Paths

    /// All candidate paths to search for kiro-cli.
    func searchPaths() -> [String] {
        var paths: [String] = []
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        // Common installation locations for kiro-cli
        let knownLocations = [
            // Direct app bundle location
            "/Applications/Kiro CLI.app/Contents/MacOS/kiro-cli",
            // User local bin (common for CLI tools)
            "\(home)/.local/bin/kiro-cli",
            // Homebrew Apple Silicon
            "/opt/homebrew/bin/kiro-cli",
            // Homebrew Intel
            "/usr/local/bin/kiro-cli",
            // System bin
            "/usr/bin/kiro-cli",
            // User bin
            "\(home)/bin/kiro-cli",
            // npm global
            "\(home)/.npm-global/bin/kiro-cli",
            "/usr/local/lib/node_modules/.bin/kiro-cli",
        ]
        paths.append(contentsOf: knownLocations)

        // Also search directories from enriched PATH
        let enrichedPATH = Self.enrichedPATH()
        for dir in enrichedPATH.split(separator: ":") {
            let candidate = "\(dir)/kiro-cli"
            if !paths.contains(candidate) {
                paths.append(candidate)
            }
        }

        return paths
    }

    // MARK: - Environment

    /// Build an enriched PATH that includes directories a GUI app typically misses.
    public static func enrichedPATH() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let existingPATH = ProcessInfo.processInfo.environment["PATH"] ?? ""

        // Directories that GUI apps typically don't have
        let extraDirs = [
            "\(home)/.local/bin",
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin",
            "\(home)/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
        ]

        var allDirs = existingPATH.split(separator: ":").map(String.init)
        for dir in extraDirs where !allDirs.contains(dir) {
            allDirs.append(dir)
        }

        return allDirs.joined(separator: ":")
    }

    /// Environment dictionary with enriched PATH for spawning child processes.
    public static func enrichedEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = enrichedPATH()
        env["TERM"] = "xterm-256color"
        return env
    }
}
