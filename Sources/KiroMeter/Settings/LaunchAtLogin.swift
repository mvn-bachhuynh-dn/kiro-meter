import Foundation
import ServiceManagement

/// Manages Launch at Login via SMAppService.
@MainActor
struct LaunchAtLogin {
    /// Register app as a login item.
    static func register() {
        do {
            try SMAppService.mainApp.register()
        } catch {
            // Silently fail - user can retry from Settings
            print("LaunchAtLogin register failed: \(error.localizedDescription)")
        }
    }

    /// Unregister app from login items.
    static func unregister() {
        do {
            try SMAppService.mainApp.unregister()
        } catch {
            print("LaunchAtLogin unregister failed: \(error.localizedDescription)")
        }
    }

    /// Current registration status.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Sync settings value with actual system state.
    static func sync(shouldEnable: Bool) {
        if shouldEnable && !isEnabled {
            register()
        } else if !shouldEnable && isEnabled {
            unregister()
        }
    }
}
