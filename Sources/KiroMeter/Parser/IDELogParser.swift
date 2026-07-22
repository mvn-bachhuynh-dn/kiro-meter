import Foundation

/// Parses Kiro IDE log files to extract enterprise policies.
///
/// The IDE logs the `EnterpriseSettingsManager` state on startup, containing
/// admin-level policies such as prompt logging status. KiroMeter reads the most
/// recent log entry to detect whether admin prompt logging is active.
///
/// Requires Kiro IDE to have been opened at least once (to generate log files).
public enum IDELogParser {

    /// Standard path to Kiro IDE logs on macOS.
    static let kiroLogsBase: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Application Support/Kiro/logs"
    }()

    /// Attempt to read the latest enterprise policies from Kiro IDE logs.
    /// Returns nil if Kiro IDE has never been opened or no policies found.
    public static func parseLatestPolicies() -> EnterprisePolicies? {
        guard let logFiles = findKiroLogFiles() else { return nil }

        // Search from newest to oldest log file
        for logFile in logFiles {
            if let policies = extractPolicies(from: logFile) {
                return policies
            }
        }

        return nil
    }

    /// Check whether Kiro IDE log directory exists (IDE has been installed/opened).
    public static var isIDELogAvailable: Bool {
        FileManager.default.fileExists(atPath: kiroLogsBase)
    }

    // MARK: - Private

    /// Find all `Kiro Logs.log` files, sorted newest first by parent directory name.
    private static func findKiroLogFiles() -> [String]? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: kiroLogsBase) else { return nil }

        // List session directories (format: 20260722T102121)
        guard let sessions = try? fm.contentsOfDirectory(atPath: kiroLogsBase) else {
            return nil
        }

        // Sort descending (newest first) by directory name (timestamp-based)
        let sortedSessions = sessions
            .filter { !$0.hasPrefix(".") }
            .sorted(by: >)

        var logFiles: [String] = []

        // For each session, find all Kiro Logs.log files
        for session in sortedSessions.prefix(5) { // Only check last 5 sessions
            let sessionPath = "\(kiroLogsBase)/\(session)"
            if let enumerator = fm.enumerator(atPath: sessionPath) {
                while let relativePath = enumerator.nextObject() as? String {
                    if relativePath.hasSuffix("kiro.kiroAgent/Kiro Logs.log") {
                        logFiles.append("\(sessionPath)/\(relativePath)")
                    }
                }
            }
        }

        return logFiles.isEmpty ? nil : logFiles
    }

    /// Extract the last EnterpriseSettingsManager policies from a log file.
    private static func extractPolicies(from logPath: String) -> EnterprisePolicies? {
        guard let data = FileManager.default.contents(atPath: logPath),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        // Find the LAST occurrence of EnterpriseSettingsManager with policies JSON
        let pattern = #"\[EnterpriseSettingsManager\] Enterprise mode enabled (\{.*\})"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        let nsContent = content as NSString
        let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsContent.length))

        // Take the last match (most recent entry in the log)
        guard let lastMatch = matches.last,
              lastMatch.numberOfRanges >= 2 else {
            return nil
        }

        let jsonRange = lastMatch.range(at: 1)
        let jsonStr = nsContent.substring(with: jsonRange)

        return parsePoliciesJSON(jsonStr)
    }

    /// Parse the policies JSON object.
    private static func parsePoliciesJSON(_ jsonStr: String) -> EnterprisePolicies? {
        guard let data = jsonStr.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let policies = dict["policies"] as? [String: Any] else {
            return nil
        }

        return EnterprisePolicies(
            promptLogging: (policies["promptLogging"] as? Bool) ?? false,
            usageAnalytics: (policies["usageAnalytics"] as? Bool) ?? false,
            contentCollection: (policies["contentCollection"] as? Bool) ?? false,
            mcpEnabled: (policies["mcpEnabled"] as? Bool) ?? true,
            webToolsEnabled: (policies["webToolsEnabled"] as? Bool) ?? true,
            codeReferenceTracker: (policies["codeReferenceTracker"] as? Bool) ?? true,
            fetchedAt: Date()
        )
    }
}
