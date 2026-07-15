import Foundation
import Testing
@testable import KiroMeter

@Suite("StatusBarPresentation")
struct StatusBarPresentationTests {

    // MARK: - Menu Bar Label

    @Test func menuBarLabel_normalSnapshot() {
        let snapshot = makeSnapshot(used: 303.12, total: 2000)
        let label = StatusBarPresentation.menuBarLabel(for: snapshot)
        #expect(label == "85%") // (2000 - 303.12) / 2000 * 100 = 84.844 -> rounded to 85
    }

    @Test func menuBarLabel_nilSnapshot() {
        let label = StatusBarPresentation.menuBarLabel(for: nil)
        #expect(label == "—")
    }

    @Test func menuBarLabel_zeroCreditTotal() {
        let snapshot = makeSnapshot(used: 0, total: 0)
        let label = StatusBarPresentation.menuBarLabel(for: snapshot)
        #expect(label == "—")
    }

    @Test func menuBarLabel_exhaustedCredits() {
        let snapshot = makeSnapshot(used: 2000, total: 2000)
        let label = StatusBarPresentation.menuBarLabel(for: snapshot)
        #expect(label == "0%")
    }

    @Test func menuBarLabel_overUsed() {
        let snapshot = makeSnapshot(used: 2100, total: 2000)
        let label = StatusBarPresentation.menuBarLabel(for: snapshot)
        #expect(label == "0%")
    }

    @Test func menuBarLabel_fullCredits() {
        let snapshot = makeSnapshot(used: 0, total: 50)
        let label = StatusBarPresentation.menuBarLabel(for: snapshot)
        #expect(label == "100%")
    }

    @Test func menuBarLabel_roundingBehavior() {
        let snapshot = makeSnapshot(used: 505, total: 1000)
        let label = StatusBarPresentation.menuBarLabel(for: snapshot)
        #expect(label == "50%")
    }

    // MARK: - Critical State

    @Test func criticalState_exhausted() {
        let snapshot = makeSnapshot(used: 2000, total: 2000)
        #expect(StatusBarPresentation.isCriticalState(for: snapshot) == true)
    }

    @Test func criticalState_normal() {
        let snapshot = makeSnapshot(used: 303, total: 2000)
        #expect(StatusBarPresentation.isCriticalState(for: snapshot) == false)
    }

    @Test func criticalState_nil() {
        #expect(StatusBarPresentation.isCriticalState(for: nil) == false)
    }

    @Test func criticalState_managedPlan() {
        let snapshot = makeSnapshot(used: 0, total: 0)
        #expect(StatusBarPresentation.isCriticalState(for: snapshot) == false)
    }

    // MARK: - Credits Label

    @Test func creditsLabel_decimalValue() {
        let snapshot = makeSnapshot(used: 303.12, total: 2000)
        let label = StatusBarPresentation.creditsLabel(for: snapshot)
        #expect(label == "303.12 / 2000 credits used")
    }

    @Test func creditsLabel_wholeNumbers() {
        let snapshot = makeSnapshot(used: 25, total: 50)
        let label = StatusBarPresentation.creditsLabel(for: snapshot)
        #expect(label == "25 / 50 credits used")
    }

    // MARK: - Plan Name Display

    @Test func displayPlanName_kiroFree() {
        #expect(StatusBarPresentation.displayPlanName("KIRO FREE") == "Kiro Free")
    }

    @Test func displayPlanName_kiroPro() {
        #expect(StatusBarPresentation.displayPlanName("KIRO PRO") == "Kiro Pro")
    }

    @Test func displayPlanName_kiroProPlus() {
        #expect(StatusBarPresentation.displayPlanName("KIRO PRO+") == "Kiro Pro+")
    }

    @Test func displayPlanName_qDeveloper() {
        #expect(StatusBarPresentation.displayPlanName("Q Developer Pro") == "Q Developer Pro")
    }

    // MARK: - Bonus Label

    @Test func bonusLabel_present() {
        let snapshot = UsageSnapshot(
            planName: "KIRO FREE",
            creditsUsed: 10,
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
        let label = StatusBarPresentation.bonusLabel(for: snapshot)
        #expect(label == "Bonus: 45.53 / 2000 used (expires in 19 days)")
    }

    @Test func bonusLabel_singularDay() {
        let snapshot = UsageSnapshot(
            planName: "KIRO FREE",
            creditsUsed: 10,
            creditsTotal: 50,
            resetDate: nil,
            bonusCreditsUsed: 5,
            bonusCreditsTotal: 10,
            bonusExpiryDays: 1,
            overagesStatus: nil,
            overageCreditsUsed: nil,
            estimatedOverageCostUSD: nil,
            manageURL: nil,
            fetchedAt: Date()
        )
        let label = StatusBarPresentation.bonusLabel(for: snapshot)
        #expect(label == "Bonus: 5 / 10 used (expires in 1 day)")
    }

    @Test func bonusLabel_absent() {
        let snapshot = makeSnapshot(used: 10, total: 50)
        let label = StatusBarPresentation.bonusLabel(for: snapshot)
        #expect(label == nil)
    }

    // MARK: - Helpers

    private func makeSnapshot(used: Double, total: Double) -> UsageSnapshot {
        UsageSnapshot(
            planName: "KIRO PRO+",
            creditsUsed: used,
            creditsTotal: total,
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
    }
}
