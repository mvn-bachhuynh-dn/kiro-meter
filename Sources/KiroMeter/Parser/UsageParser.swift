import Foundation

/// Errors that can occur when parsing Kiro CLI output.
public enum UsageParseError: Error, Equatable, Sendable {
    case emptyOutput
    case notLoggedIn
    case backendError(String)
    case unrecognizedFormat(String)
}

/// Parses raw output from `kiro-cli chat --no-interactive "/usage"` into a UsageSnapshot.
public enum UsageParser {

    /// Parse combined stdout+stderr output into a UsageSnapshot.
    /// Throws UsageParseError for known error conditions.
    public static func parse(_ rawOutput: String) throws -> UsageSnapshot {
        let stripped = stripANSI(rawOutput)
        let trimmed = stripped.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw UsageParseError.emptyOutput
        }

        // Check for authentication errors
        if isNotLoggedIn(trimmed) {
            throw UsageParseError.notLoggedIn
        }

        // Check for backend errors
        if let backendError = detectBackendError(trimmed) {
            throw UsageParseError.backendError(backendError)
        }

        // Try parsing known formats
        let planName = parsePlanName(from: trimmed)
        let credits = parseCredits(from: trimmed)
        let resetDate = parseResetDate(from: trimmed)
        let bonus = parseBonusCredits(from: trimmed)
        let overage = parseOverage(from: trimmed)
        let manageURL = parseManageURL(from: trimmed)

        // Check for managed plan (no metrics but valid format)
        let isManagedPlan = trimmed.lowercased().contains("managed by admin")
            || trimmed.lowercased().contains("managed by organization")

        if let credits {
            return UsageSnapshot(
                planName: planName ?? "Kiro",
                creditsUsed: credits.used,
                creditsTotal: credits.total,
                resetDate: resetDate,
                bonusCreditsUsed: bonus?.used,
                bonusCreditsTotal: bonus?.total,
                bonusExpiryDays: bonus?.expiryDays,
                overagesStatus: overage?.status,
                overageCreditsUsed: overage?.creditsUsed,
                estimatedOverageCostUSD: overage?.estimatedCostUSD,
                manageURL: manageURL,
                fetchedAt: Date()
            )
        }

        // Managed plan without metrics
        if isManagedPlan, planName != nil {
            return UsageSnapshot(
                planName: planName!,
                creditsUsed: 0,
                creditsTotal: 0,
                resetDate: nil,
                bonusCreditsUsed: bonus?.used,
                bonusCreditsTotal: bonus?.total,
                bonusExpiryDays: bonus?.expiryDays,
                overagesStatus: nil,
                overageCreditsUsed: nil,
                estimatedOverageCostUSD: nil,
                manageURL: nil,
                fetchedAt: Date()
            )
        }

        // Could not parse any meaningful data
        throw UsageParseError.unrecognizedFormat(
            "No recognizable usage patterns found. Kiro CLI output format may have changed."
        )
    }

    // MARK: - ANSI Stripping

    /// Remove ANSI escape sequences and OSC sequences from text.
    public static func stripANSI(_ text: String) -> String {
        // Match: ESC[...m (SGR), ESC[...X (other CSI), ESC]...BEL (OSC)
        let pattern = #"\x1B\[[0-9;?]*[A-Za-z]|\x1B\].*?\x07|\x1B\[[0-9;]*m"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }

    // MARK: - Plan Name

    static func parsePlanName(from text: String) -> String? {
        // Format: "Estimated Usage | resets on YYYY-MM-DD | KIRO PRO+"
        if let match = text.range(
            of: #"Estimated Usage[^\n|]*\|[^\n|]*\|[ \t]*([A-Z][A-Z0-9 +]+)"#,
            options: .regularExpression
        ) {
            let line = String(text[match])
            if let plan = line.split(separator: "|").last?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !plan.isEmpty {
                return plan
            }
        }

        // Format: "| KIRO FREE |" (legacy)
        if let match = text.range(
            of: #"\|[ \t]*(KIRO[ \t]+[\w+]+)[ \t]*\|?"#,
            options: .regularExpression
        ) {
            let raw = String(text[match])
                .replacingOccurrences(of: "|", with: "")
                .trimmingCharacters(in: .whitespaces)
            if !raw.isEmpty { return raw }
        }

        // Format: "Plan: Q Developer Pro" (new format kiro-cli 1.24+)
        if let match = text.range(of: #"Plan:[ \t]*(.+)"#, options: .regularExpression) {
            let line = String(text[match])
            let planLine = line.replacingOccurrences(of: "Plan:", with: "")
                .trimmingCharacters(in: .whitespaces)
            if let firstLine = planLine.split(separator: "\n").first {
                return String(firstLine).trimmingCharacters(in: .whitespaces)
            }
        }

        return nil
    }

    // MARK: - Credits

    struct ParsedCredits {
        let used: Double
        let total: Double
    }

    static func parseCredits(from text: String) -> ParsedCredits? {
        // Format: "(303.12 of 2000 covered in plan)"
        let pattern = #"\((\d+\.?\d*)\s+of\s+(\d+\.?\d*)\s+covered"#
        guard let match = text.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        let creditsStr = String(text[match])
        let numbers = creditsStr.matches(of: /(\d+\.?\d*)/)
        guard numbers.count >= 2,
              let used = Double(String(numbers[0].output.1)),
              let total = Double(String(numbers[1].output.1))
        else { return nil }
        return ParsedCredits(used: used, total: total)
    }

    // MARK: - Reset Date

    static func parseResetDate(from text: String) -> Date? {
        // Format: "resets on 2026-08-01"
        if let match = text.range(of: #"resets on (\d{4}-\d{2}-\d{2})"#, options: .regularExpression) {
            let dateStr = String(text[match])
            if let dateRange = dateStr.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression) {
                return parseISO(String(dateStr[dateRange]))
            }
        }

        // Format: "resets on 01/15" (MM/DD, assumes current or next year)
        if let match = text.range(of: #"resets on (\d{2}/\d{2})"#, options: .regularExpression) {
            let dateStr = String(text[match])
            if let dateRange = dateStr.range(of: #"\d{2}/\d{2}"#, options: .regularExpression) {
                return parseMMDD(String(dateStr[dateRange]))
            }
        }

        return nil
    }

    // MARK: - Bonus Credits

    struct ParsedBonus {
        let used: Double
        let total: Double
        let expiryDays: Int?
    }

    static func parseBonusCredits(from text: String) -> ParsedBonus? {
        // Format: "Bonus credits: 45.53/2000 credits used" or with emoji prefix
        // Also handles: "🎁 Bonus credits: 45.53/2000 credits used, expires in 19 days"
        let pattern = #"[Bb]onus credits?:\s*(\d+\.?\d*)/(\d+\.?\d*)"#
        guard let match = text.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        let bonusStr = String(text[match])
        let numbers = bonusStr.matches(of: /(\d+\.?\d*)/)
        guard numbers.count >= 2,
              let used = Double(String(numbers[0].output.1)),
              let total = Double(String(numbers[1].output.1))
        else { return nil }

        var expiryDays: Int?
        if let expiryMatch = text.range(of: #"expires in (\d+) days?"#, options: .regularExpression) {
            let expiryStr = String(text[expiryMatch])
            if let numMatch = expiryStr.range(of: #"\d+"#, options: .regularExpression) {
                expiryDays = Int(String(expiryStr[numMatch]))
            }
        }

        return ParsedBonus(used: used, total: total, expiryDays: expiryDays)
    }

    // MARK: - Overages

    struct ParsedOverage {
        let status: String
        let creditsUsed: Double?
        let estimatedCostUSD: Double?
    }

    static func parseOverage(from text: String) -> ParsedOverage? {
        // Format: "Overages: Enabled billed at $0.04 per request"
        guard let match = text.range(
            of: #"(?i)Overages:\s*([^\n]+)"#,
            options: .regularExpression
        ) else { return nil }

        let line = String(text[match])
        let status = line.replacingOccurrences(
            of: #"(?i)Overages:\s*"#, with: "", options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        // "Credits used: 40.29"
        var creditsUsed: Double?
        if let cuMatch = text.range(
            of: #"(?i)Credits used:\s*(\d+\.?\d*)"#,
            options: .regularExpression
        ) {
            let cuStr = String(text[cuMatch])
            if let numMatch = cuStr.range(of: #"\d+\.?\d*"#, options: .regularExpression) {
                creditsUsed = Double(String(cuStr[numMatch]))
            }
        }

        // "Est. cost: $1.61 USD"
        var costUSD: Double?
        if let costMatch = text.range(
            of: #"(?i)Est\.\s*cost:\s*\$?(\d+\.?\d*)"#,
            options: .regularExpression
        ) {
            let costStr = String(text[costMatch])
            let numbers = costStr.matches(of: /(\d+\.?\d*)/)
            if let last = numbers.last {
                costUSD = Double(String(last.output.1))
            }
        }

        return ParsedOverage(status: status, creditsUsed: creditsUsed, estimatedCostUSD: costUSD)
    }

    // MARK: - Manage URL

    static func parseManageURL(from text: String) -> String? {
        if text.contains("https://app.kiro.dev/account/usage") {
            return "https://app.kiro.dev/account/usage"
        }
        return nil
    }

    // MARK: - Auth Detection

    static func isNotLoggedIn(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return lowered.contains("not logged in")
            || lowered.contains("login required")
            || lowered.contains("failed to initialize auth portal")
            || lowered.contains("kiro-cli login")
            || lowered.contains("oauth error")
    }

    // MARK: - Backend Error Detection

    static func detectBackendError(_ text: String) -> String? {
        let lowered = text.lowercased()
        if lowered.contains("could not retrieve usage information") {
            return "Could not retrieve usage information from backend."
        }
        return nil
    }

    // MARK: - Date Helpers

    private static func parseISO(_ dateStr: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateStr)
    }

    private static func parseMMDD(_ dateStr: String) -> Date? {
        let parts = dateStr.split(separator: "/")
        guard parts.count == 2,
              let month = Int(parts[0]),
              let day = Int(parts[1])
        else { return nil }

        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)

        var components = DateComponents()
        components.month = month
        components.day = day
        components.year = currentYear

        if let date = calendar.date(from: components), date > now {
            return date
        }
        // If past, assume next year
        components.year = currentYear + 1
        return calendar.date(from: components)
    }
}
