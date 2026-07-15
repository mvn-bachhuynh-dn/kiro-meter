import Foundation
import SwiftUI

/// Represents the current state of usage data.
enum UsageState: Sendable {
    case idle
    case loading
    case loaded(UsageSnapshot)
    case error(String, lastGood: UsageSnapshot?)
}

@MainActor
@Observable
final class UsageViewModel {
    private(set) var snapshot: UsageSnapshot?
    private(set) var lastError: String?
    private(set) var isLoading: Bool = false
    private(set) var lastFetchedAt: Date?

    /// Whether the current snapshot is stale (kept from a previous successful fetch).
    var isStale: Bool {
        lastError != nil && snapshot != nil
    }

    private let usageService: UsageService
    private var fetchTask: Task<Void, Never>?

    init(customExecutablePath: String? = nil) {
        self.usageService = UsageService(customExecutablePath: customExecutablePath)
    }

    /// Trigger a refresh. Prevents concurrent refreshes.
    func refresh() {
        guard !isLoading else { return }
        fetchTask?.cancel()
        fetchTask = Task {
            await performFetch()
        }
    }

    /// Async fetch - called from Task or scheduler.
    func performFetch() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let newSnapshot = try await usageService.fetchUsage()
            self.snapshot = newSnapshot
            self.lastError = nil
            self.lastFetchedAt = Date()
        } catch is CancellationError {
            // Silently ignore cancellation
        } catch {
            // Keep last-known-good snapshot, record error
            self.lastError = error.localizedDescription
            self.lastFetchedAt = Date()
        }
    }

    /// Get diagnostics about the CLI executable.
    func getDiagnostics() async -> (path: String?, version: String?) {
        await usageService.diagnostics()
    }

    /// User-friendly error guidance based on the current error.
    var errorGuidance: String? {
        guard let error = lastError else { return nil }
        if error.contains("not found") {
            return "Install Kiro CLI from kiro.dev or set the path in Settings."
        }
        if error.contains("Not logged in") || error.contains("login") {
            return "Open Terminal and run: kiro-cli login"
        }
        if error.contains("timed out") {
            return "Check your internet connection and try again."
        }
        return nil
    }
}
