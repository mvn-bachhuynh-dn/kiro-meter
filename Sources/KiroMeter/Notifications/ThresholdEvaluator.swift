import Foundation

/// Evaluates whether a low-credit notification should be sent.
/// Fires once per threshold crossing; rearms when credits go back up or reset date changes.
@MainActor
final class ThresholdEvaluator {
    private let hasNotifiedKey = "hasNotifiedForCurrentCycle"
    private let lastResetDateKey = "lastNotifiedResetDate"

    /// Evaluate snapshot against threshold. Returns true if notification should fire.
    func shouldNotify(snapshot: UsageSnapshot, threshold: Int) -> Bool {
        guard let remainingPercent = snapshot.remainingPercent else { return false }

        let hasNotified = UserDefaults.standard.bool(forKey: hasNotifiedKey)

        // Check if reset date changed (new billing cycle) -> rearm
        if let resetDate = snapshot.resetDate {
            let storedReset = UserDefaults.standard.string(forKey: lastResetDateKey) ?? ""
            let currentReset = ISO8601DateFormatter().string(from: resetDate)
            if storedReset != currentReset {
                // New cycle, rearm
                UserDefaults.standard.set(false, forKey: hasNotifiedKey)
                UserDefaults.standard.set(currentReset, forKey: lastResetDateKey)
                return remainingPercent <= Double(threshold)
            }
        }

        // Check if credits went back above threshold -> rearm
        if hasNotified && remainingPercent > Double(threshold) {
            UserDefaults.standard.set(false, forKey: hasNotifiedKey)
            return false
        }

        // Already notified for this crossing
        if hasNotified { return false }

        // Check threshold crossing
        if remainingPercent <= Double(threshold) {
            return true
        }

        return false
    }

    /// Mark that notification was sent.
    func markNotified() {
        UserDefaults.standard.set(true, forKey: hasNotifiedKey)
    }
}
