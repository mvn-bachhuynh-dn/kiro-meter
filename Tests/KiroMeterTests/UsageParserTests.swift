import Foundation
import Testing
@testable import KiroMeter

@Suite("UsageParser")
struct UsageParserTests {

    // MARK: - Real Output from Current Machine (KIRO PRO+)

    @Test func parsesCurrentMachineOutput() throws {
        let output = """
        \u{001B}[1mEstimated Usage\u{001B}[0m | resets on 2026-08-01 | \u{001B}[38;5;141mKIRO PRO+\u{001B}[0m
        \u{001B}[1mCredits\u{001B}[0m (303.12 of 2000 covered in plan)
        \u{001B}[38;5;141m████████████\u{001B}[38;5;244m████████████████████████████████████████████████████████████████████\u{001B}[0m 15%

        Since your account is through your organization, for account management please contact your account administrator.

        Tip: to see context window usage, run \u{001B}[38;5;141m/context\u{001B}[0m
        """
        let snapshot = try UsageParser.parse(output)
        #expect(snapshot.planName == "KIRO PRO+")
        #expect(snapshot.creditsUsed == 303.12)
        #expect(snapshot.creditsTotal == 2000)
        #expect(snapshot.creditsRemaining == 1696.88)
        // remainingPercent = 1696.88 / 2000 * 100 = 84.844
        #expect(snapshot.remainingPercent != nil)
        #expect(Int(snapshot.remainingPercent!.rounded()) == 85)
        #expect(snapshot.isCritical == false)
        #expect(snapshot.resetDate != nil)
        #expect(snapshot.bonusCreditsUsed == nil)
    }

    // MARK: - Kiro CLI 2.x Format with Bonus and Overages

    @Test func parsesKiroCli2xWithBonus() throws {
        let output = """
        Estimated Usage | resets on 2026-06-01 | KIRO FREE
        🎁 Bonus credits: 45.53/2000 credits used, expires in 19 days
        Credits (0.17 of 50 covered in plan)
        ████████████████████████████████████████████████████████████████████████████████ 0%
        Overages: Disabled
        To manage your plan or configure overages navigate to https://app.kiro.dev/account/usage
        """
        let snapshot = try UsageParser.parse(output)
        #expect(snapshot.planName == "KIRO FREE")
        #expect(snapshot.creditsUsed == 0.17)
        #expect(snapshot.creditsTotal == 50)
        #expect(snapshot.bonusCreditsUsed == 45.53)
        #expect(snapshot.bonusCreditsTotal == 2000)
        #expect(snapshot.bonusExpiryDays == 19)
        #expect(snapshot.overagesStatus == "Disabled")
        #expect(snapshot.manageURL == "https://app.kiro.dev/account/usage")
        // remaining = 49.83 / 50 * 100 = 99.66
        #expect(Int(snapshot.remainingPercent!.rounded()) == 100)
    }

    @Test func parsesOverageCreditsAndCost() throws {
        let output = """
        Estimated Usage | resets on 2026-06-01 | KIRO PRO
        Credits (1000.00 of 1000 covered in plan)
        ████████████████████████████████████████████████████████████████████████████████ 100%
        Overages: Enabled billed at $0.04 per request
        Credits used: 40.29
        Est. cost: $1.61 USD
        To manage your plan or configure overages navigate to https://app.kiro.dev/account/usage
        """
        let snapshot = try UsageParser.parse(output)
        #expect(snapshot.planName == "KIRO PRO")
        #expect(snapshot.creditsUsed == 1000)
        #expect(snapshot.creditsTotal == 1000)
        #expect(snapshot.isCritical == true)
        #expect(snapshot.remainingPercent == 0)
        #expect(snapshot.overagesStatus == "Enabled billed at $0.04 per request")
        #expect(snapshot.overageCreditsUsed == 40.29)
        #expect(snapshot.estimatedOverageCostUSD == 1.61)
    }

    // MARK: - Legacy Format

    @Test func parsesLegacyFormat() throws {
        let output = """
        | KIRO FREE |
        ████████████████████████████████████████████████████ 25%
        (12.50 of 50 covered in plan), resets on 01/15
        """
        let snapshot = try UsageParser.parse(output)
        #expect(snapshot.planName == "KIRO FREE")
        #expect(snapshot.creditsUsed == 12.50)
        #expect(snapshot.creditsTotal == 50)
        #expect(snapshot.resetDate != nil)
    }

    @Test func parsesLegacyWithBonusCredits() throws {
        let output = """
        | KIRO PRO |
        ████████████████████████████████████████████████████ 80%
        (40.00 of 50 covered in plan), resets on 02/01
        Bonus credits: 5.00/10 credits used, expires in 7 days
        """
        let snapshot = try UsageParser.parse(output)
        #expect(snapshot.planName == "KIRO PRO")
        #expect(snapshot.creditsUsed == 40.00)
        #expect(snapshot.creditsTotal == 50)
        #expect(snapshot.bonusCreditsUsed == 5.00)
        #expect(snapshot.bonusCreditsTotal == 10)
        #expect(snapshot.bonusExpiryDays == 7)
    }

    @Test func parsesBonusSingularDay() throws {
        let output = """
        | KIRO FREE |
        (5.00 of 50 covered in plan)
        Bonus credits: 2.00/5 credits used, expires in 1 day
        """
        let snapshot = try UsageParser.parse(output)
        #expect(snapshot.bonusExpiryDays == 1)
    }

    // MARK: - New Format (Managed/Q Developer Plans)

    @Test func parsesManagedPlan() throws {
        let output = """
        Plan: Q Developer Pro
        Your plan is managed by admin
        Tip: to see context window usage, run /context
        """
        let snapshot = try UsageParser.parse(output)
        #expect(snapshot.planName == "Q Developer Pro")
        #expect(snapshot.creditsTotal == 0)
        #expect(snapshot.creditsUsed == 0)
        #expect(snapshot.remainingPercent == nil) // unavailable
        #expect(snapshot.isCritical == false)
    }

    @Test func parsesManagedPlanWithMetrics() throws {
        let output = """
        Plan: Q Developer Enterprise
        Your plan is managed by admin
        ████████████████████████████████████████████████████ 40%
        (20.00 of 50 covered in plan), resets on 03/15
        """
        let snapshot = try UsageParser.parse(output)
        #expect(snapshot.planName == "Q Developer Enterprise")
        #expect(snapshot.creditsUsed == 20)
        #expect(snapshot.creditsTotal == 50)
    }

    // MARK: - ANSI Code Stripping

    @Test func stripsANSICodes() throws {
        let output = """
        \u{001B}[32m| KIRO FREE |\u{001B}[0m
        \u{001B}[38;5;11m████████████████████████████████████████████████████\u{001B}[0m 50%
        (25.00 of 50 covered in plan), resets on 03/15
        """
        let snapshot = try UsageParser.parse(output)
        #expect(snapshot.planName == "KIRO FREE")
        #expect(snapshot.creditsUsed == 25.00)
        #expect(snapshot.creditsTotal == 50)
    }

    @Test func stripsOSCSequences() {
        let input = "Hello\u{001B}]0;title\u{0007}World"
        let result = UsageParser.stripANSI(input)
        #expect(result == "HelloWorld")
    }

    // MARK: - Error Conditions

    @Test func throwsOnEmptyOutput() {
        #expect(throws: UsageParseError.emptyOutput) {
            try UsageParser.parse("")
        }
    }

    @Test func throwsOnWhitespaceOnly() {
        #expect(throws: UsageParseError.emptyOutput) {
            try UsageParser.parse("   \n\t  ")
        }
    }

    @Test func throwsNotLoggedIn() {
        let output = """
        Failed to initialize auth portal. Please try again with:
          kiro-cli login --use-device-flow
        error: OAuth error: All callback ports are in use.
        """
        #expect(throws: UsageParseError.notLoggedIn) {
            try UsageParser.parse(output)
        }
    }

    @Test func throwsNotLoggedIn_simpleMessage() {
        #expect(throws: UsageParseError.notLoggedIn) {
            try UsageParser.parse("Not logged in")
        }
    }

    @Test func throwsBackendError() {
        let output = """
        ⚠️ Warning: Could not retrieve usage information from backend
        Error: dispatch failure (io error): an i/o error occurred
        """
        #expect { try UsageParser.parse(output) } throws: { error in
            guard case UsageParseError.backendError = error else { return false }
            return true
        }
    }

    @Test func throwsUnrecognizedFormat() {
        let output = """
        Welcome to Kiro!
        Your account is active.
        Usage: unknown format
        """
        #expect { try UsageParser.parse(output) } throws: { error in
            guard case UsageParseError.unrecognizedFormat = error else { return false }
            return true
        }
    }

    // MARK: - Edge Cases

    @Test func handlesDecimalCredits() throws {
        let output = """
        Estimated Usage | resets on 2026-07-01 | KIRO PRO+
        Credits (0.01 of 2000 covered in plan)
        """
        let snapshot = try UsageParser.parse(output)
        #expect(snapshot.creditsUsed == 0.01)
        #expect(snapshot.creditsTotal == 2000)
    }

    @Test func handlesFullCreditsUsed() throws {
        let output = """
        Estimated Usage | resets on 2026-07-01 | KIRO PRO
        Credits (2000 of 2000 covered in plan)
        """
        let snapshot = try UsageParser.parse(output)
        #expect(snapshot.creditsUsed == 2000)
        #expect(snapshot.creditsTotal == 2000)
        #expect(snapshot.isCritical == true)
        #expect(snapshot.remainingPercent == 0)
    }

    @Test func handlesMissingResetDate() throws {
        let output = """
        | KIRO FREE |
        (25.00 of 50 covered in plan)
        """
        let snapshot = try UsageParser.parse(output)
        #expect(snapshot.resetDate == nil)
        #expect(snapshot.creditsUsed == 25)
    }

    @Test func resetDateISO() throws {
        let output = """
        Estimated Usage | resets on 2026-08-01 | KIRO PRO+
        Credits (100 of 2000 covered in plan)
        """
        let snapshot = try UsageParser.parse(output)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: snapshot.resetDate!)
        #expect(components.year == 2026)
        #expect(components.month == 8)
        #expect(components.day == 1)
    }

    @Test func bonusWithoutExpiry() throws {
        let output = """
        | KIRO FREE |
        (30.00 of 50 covered in plan)
        Bonus credits: 2.00/5 credits used
        """
        let snapshot = try UsageParser.parse(output)
        #expect(snapshot.bonusCreditsUsed == 2.0)
        #expect(snapshot.bonusCreditsTotal == 5.0)
        #expect(snapshot.bonusExpiryDays == nil)
    }

    // MARK: - Snapshot Computed Properties

    @Test func remainingPercentCalculation() {
        let snapshot = UsageSnapshot(
            planName: "TEST",
            creditsUsed: 303.12,
            creditsTotal: 2000,
            resetDate: nil,
            bonusCreditsUsed: nil,
            bonusCreditsTotal: nil,
            bonusExpiryDays: nil,
            overagesStatus: nil,
            overageCreditsUsed: nil,
            estimatedOverageCostUSD: nil,
            manageURL: nil,
            fetchedAt: Date()
        )
        // 1696.88 / 2000 * 100 = 84.844
        #expect(abs(snapshot.remainingPercent! - 84.844) < 0.001)
    }

    @Test func bonusCreditsRemaining() {
        let snapshot = UsageSnapshot(
            planName: "TEST",
            creditsUsed: 0,
            creditsTotal: 50,
            resetDate: nil,
            bonusCreditsUsed: 45.53,
            bonusCreditsTotal: 2000,
            bonusExpiryDays: 19,
            overagesStatus: nil,
            overageCreditsUsed: nil,
            estimatedOverageCostUSD: nil,
            manageURL: nil,
            fetchedAt: Date()
        )
        #expect(snapshot.bonusCreditsRemaining == 1954.47)
    }
}
