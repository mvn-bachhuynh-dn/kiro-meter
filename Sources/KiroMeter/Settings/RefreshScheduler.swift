import Foundation

/// Periodically triggers usage refresh based on configured interval.
@MainActor
final class RefreshScheduler {
    private var timerTask: Task<Void, Never>?
    private var lastRefreshTime: Date?

    /// Start or restart the scheduler with a new interval.
    func start(interval: RefreshInterval, action: @escaping @MainActor () async -> Void) {
        stop()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: interval.duration)
                guard !Task.isCancelled else { break }

                // Coalesce: skip if a manual refresh happened recently (within 30s)
                if let last = lastRefreshTime,
                   Date().timeIntervalSince(last) < 30 {
                    continue
                }

                await action()
                lastRefreshTime = Date()
            }
        }
    }

    /// Stop the scheduler.
    func stop() {
        timerTask?.cancel()
        timerTask = nil
    }

    /// Record that a manual refresh just happened (for coalescing).
    func recordManualRefresh() {
        lastRefreshTime = Date()
    }
}
