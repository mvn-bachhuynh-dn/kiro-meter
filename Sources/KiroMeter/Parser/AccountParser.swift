import Foundation

/// Parses output from `kiro-cli whoami` and `kiro-cli settings list -f json`
/// into AccountInfo and PrivacySettings models.
public enum AccountParser {

    // MARK: - Account Info (from `kiro-cli whoami`)

    /// Parse `kiro-cli whoami` output into an AccountInfo.
    ///
    /// Expected format:
    /// ```
    /// Logged in with IAM Identity Center (https://d-90660851ca.awsapps.com/start)
    /// Email: bach.huynhvan+1@gmail.com
    ///
    /// Profile:
    /// KiroProfile-us-east-1
    /// arn:aws:codewhisperer:us-east-1:891377004109:profile/DHV7EQ7EKEVD
    /// ```
    public static func parseWhoami(_ rawOutput: String) -> AccountInfo? {
        let stripped = UsageParser.stripANSI(rawOutput)
        let trimmed = stripped.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else { return nil }

        // Check for not-logged-in state
        let lowered = trimmed.lowercased()
        if lowered.contains("not logged in") || lowered.contains("login required") {
            return nil
        }

        let email = parseEmail(from: trimmed)
        let startURL = parseStartURL(from: trimmed)
        let profileName = parseProfileName(from: trimmed)
        let profileARN = parseProfileARN(from: trimmed)
        let region = parseRegion(fromARN: profileARN, profileName: profileName)

        // If we couldn't extract anything meaningful, return nil
        guard email != nil || startURL != nil || profileName != nil else {
            return nil
        }

        return AccountInfo(
            email: email,
            startURL: startURL,
            region: region,
            profileName: profileName,
            profileARN: profileARN
        )
    }

    // MARK: - Privacy Settings (from `kiro-cli settings list -f json`)

    /// Parse `kiro-cli settings list -f json` output into PrivacySettings.
    /// Falls back to safe defaults (assumes enabled) if parsing fails.
    public static func parseSettings(_ rawOutput: String) -> PrivacySettings? {
        let stripped = UsageParser.stripANSI(rawOutput)
        let trimmed = stripped.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else { return nil }

        // Find the JSON object in the output (may have leading/trailing noise)
        guard let jsonStart = trimmed.firstIndex(of: "{"),
              let jsonEnd = trimmed.lastIndex(of: "}") else {
            return nil
        }

        let jsonStr = String(trimmed[jsonStart...jsonEnd])
        guard let data = jsonStr.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // telemetry.enabled: defaults to true if not found (assume worst case)
        let telemetryEnabled: Bool
        if let val = dict["telemetry.enabled"] {
            telemetryEnabled = boolValue(val) ?? true
        } else {
            telemetryEnabled = true // default: assume enabled if unset
        }

        // codeWhisperer.shareCodeWhispererContentWithAWS: defaults to true if not found
        let promptLoggingEnabled: Bool
        if let val = dict["codeWhisperer.shareCodeWhispererContentWithAWS"] {
            promptLoggingEnabled = boolValue(val) ?? true
        } else {
            promptLoggingEnabled = true // default: assume enabled if unset
        }

        return PrivacySettings(
            telemetryEnabled: telemetryEnabled,
            promptLoggingEnabled: promptLoggingEnabled
        )
    }

    // MARK: - Private Helpers

    private static func parseEmail(from text: String) -> String? {
        // Format: "Email: user@example.com"
        guard let match = text.range(
            of: #"Email:\s*(\S+@\S+)"#,
            options: .regularExpression
        ) else { return nil }

        let line = String(text[match])
        return line.replacingOccurrences(
            of: #"Email:\s*"#, with: "", options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseStartURL(from text: String) -> String? {
        // Format: "Logged in with IAM Identity Center (https://....awsapps.com/start)"
        guard let match = text.range(
            of: #"\(https?://[^)]+\)"#,
            options: .regularExpression
        ) else { return nil }

        var url = String(text[match])
        // Remove parentheses
        url.removeFirst()
        url.removeLast()
        return url.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseProfileName(from text: String) -> String? {
        // The profile name is the first non-empty line after "Profile:"
        let lines = text.components(separatedBy: .newlines)
        var foundProfileHeader = false
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.hasPrefix("Profile:") {
                // Check if there's content on the same line
                let rest = trimmedLine.replacingOccurrences(of: "Profile:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if !rest.isEmpty && !rest.hasPrefix("arn:") {
                    return rest
                }
                foundProfileHeader = true
                continue
            }
            if foundProfileHeader {
                if trimmedLine.isEmpty { continue }
                if trimmedLine.hasPrefix("arn:") { break }
                return trimmedLine
            }
        }
        return nil
    }

    private static func parseProfileARN(from text: String) -> String? {
        // Format: "arn:aws:codewhisperer:us-east-1:891377004109:profile/DHV7EQ7EKEVD"
        guard let match = text.range(
            of: #"arn:aws:\w+:[^:]+:[^:]+:profile/\S+"#,
            options: .regularExpression
        ) else { return nil }
        return String(text[match])
    }

    private static func parseRegion(fromARN arn: String?, profileName: String?) -> String? {
        // Try from ARN first: arn:aws:codewhisperer:REGION:account:profile/id
        if let arn,
           let match = arn.range(of: #"arn:aws:\w+:([^:]+):"#, options: .regularExpression) {
            let segment = String(arn[match])
            let parts = segment.split(separator: ":")
            if parts.count >= 4 {
                return String(parts[3])
            }
        }

        // Fallback: extract from profile name like "KiroProfile-us-east-1"
        if let profileName,
           let match = profileName.range(
               of: #"[a-z]{2}-[a-z]+-\d+"#,
               options: .regularExpression
           ) {
            return String(profileName[match])
        }

        return nil
    }

    /// Coerce various JSON value types to Bool.
    private static func boolValue(_ value: Any) -> Bool? {
        if let b = value as? Bool { return b }
        if let s = value as? String {
            switch s.lowercased() {
            case "true", "1", "yes": return true
            case "false", "0", "no": return false
            default: return nil
            }
        }
        if let n = value as? NSNumber { return n.boolValue }
        return nil
    }
}
