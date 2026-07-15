import Foundation
import UserNotifications

/// Manages macOS notifications for KiroMeter.
final class NotificationClient: NSObject, @unchecked Sendable {
    static let shared = NotificationClient()

    private override init() {
        super.init()
    }

    /// Request notification permission. Only call when user enables notifications.
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            return granted
        } catch {
            return false
        }
    }

    /// Check if notifications are authorized.
    func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    /// Send a low credit alert notification.
    func sendLowCreditAlert(remaining: Double, total: Double, percent: Double) async {
        let content = UNMutableNotificationContent()
        content.title = "KiroMeter"
        content.body = String(
            format: "Credit remaining: %.0f%% (%.2f / %.0f credits left)",
            percent, remaining, total
        )
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "kirometer-low-credit-\(UUID().uuidString)",
            content: content,
            trigger: nil // Deliver immediately
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
}
