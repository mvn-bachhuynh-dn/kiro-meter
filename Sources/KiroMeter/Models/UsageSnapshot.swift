import Foundation

/// Represents a parsed snapshot of Kiro credit usage at a point in time.
public struct UsageSnapshot: Sendable, Equatable {
    public let planName: String
    public let creditsUsed: Double
    public let creditsTotal: Double
    public let resetDate: Date?
    public let bonusCreditsUsed: Double?
    public let bonusCreditsTotal: Double?
    public let bonusExpiryDays: Int?
    public let overagesStatus: String?
    public let overageCreditsUsed: Double?
    public let estimatedOverageCostUSD: Double?
    public let manageURL: String?
    public let fetchedAt: Date

    public var creditsRemaining: Double {
        max(creditsTotal - creditsUsed, 0)
    }

    /// Remaining percentage calculated from used/total (more accurate than CLI-rounded value).
    /// Returns nil when total is zero (managed plan without metrics).
    public var remainingPercent: Double? {
        guard creditsTotal > 0 else { return nil }
        return (creditsRemaining / creditsTotal) * 100.0
    }

    /// Used percentage calculated from used/total.
    public var usedPercent: Double? {
        guard creditsTotal > 0 else { return nil }
        return (creditsUsed / creditsTotal) * 100.0
    }

    /// Whether the monthly credits are fully exhausted.
    public var isCritical: Bool {
        creditsTotal > 0 && creditsRemaining <= 0
    }

    public var bonusCreditsRemaining: Double? {
        guard let used = bonusCreditsUsed, let total = bonusCreditsTotal else { return nil }
        return max(total - used, 0)
    }
}
