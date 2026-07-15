import Foundation

/// Formats UsageSnapshot data for display in the status bar and detail popover.
public enum StatusBarPresentation {
    /// Menu bar label: "85%" or "—" when unavailable.
    public static func menuBarLabel(for snapshot: UsageSnapshot?) -> String {
        guard let snapshot, let percent = snapshot.remainingPercent else {
            return "—"
        }
        return "\(Int(percent.rounded()))%"
    }

    /// Whether the status bar should show critical (red) state.
    public static func isCriticalState(for snapshot: UsageSnapshot?) -> Bool {
        snapshot?.isCritical ?? false
    }

    /// Formatted credits string: "303.12 / 2000"
    public static func creditsLabel(for snapshot: UsageSnapshot) -> String {
        let used = formatCredits(snapshot.creditsUsed)
        let total = formatCredits(snapshot.creditsTotal)
        return "\(used) / \(total) credits used"
    }

    /// Formatted remaining credits: "1696.88 remaining"
    public static func remainingLabel(for snapshot: UsageSnapshot) -> String {
        let remaining = formatCredits(snapshot.creditsRemaining)
        return "\(remaining) remaining"
    }

    /// Reset date label: "Resets on Aug 1, 2026" or nil
    public static func resetLabel(for snapshot: UsageSnapshot) -> String? {
        guard let date = snapshot.resetDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "Resets on \(formatter.string(from: date))"
    }

    /// Bonus credits label if present: "Bonus: 45.53 / 2000 (expires in 19 days)"
    public static func bonusLabel(for snapshot: UsageSnapshot) -> String? {
        guard let used = snapshot.bonusCreditsUsed,
              let total = snapshot.bonusCreditsTotal else { return nil }
        var label = "Bonus: \(formatCredits(used)) / \(formatCredits(total)) used"
        if let days = snapshot.bonusExpiryDays {
            label += " (expires in \(days) \(days == 1 ? "day" : "days"))"
        }
        return label
    }

    /// Plan display name, title-cased: "Kiro Pro+"
    public static func displayPlanName(_ planName: String) -> String {
        let cleaned = planName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.lowercased().contains("kiro") else { return cleaned }
        return cleaned
            .split(separator: " ")
            .map { word in
                if word.uppercased() == "KIRO" { return "Kiro" }
                // Keep symbols like "+" at end
                return word.prefix(1).uppercased() + word.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }

    // MARK: - Private

    private static func formatCredits(_ value: Double) -> String {
        if value == value.rounded() && value < 10000 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }
}
