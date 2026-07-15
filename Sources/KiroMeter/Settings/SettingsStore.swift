import Foundation
import SwiftUI

/// Refresh interval options.
public enum RefreshInterval: Int, CaseIterable, Sendable {
    case minutes1 = 1
    case minutes5 = 5
    case minutes15 = 15
    case minutes30 = 30

    public var label: String {
        switch self {
        case .minutes1: "1 minute"
        case .minutes5: "5 minutes"
        case .minutes15: "15 minutes"
        case .minutes30: "30 minutes"
        }
    }

    public var duration: Duration {
        .seconds(rawValue * 60)
    }
}

/// Persistent settings for KiroMeter.
@MainActor
@Observable
final class SettingsStore {
    // Stored via UserDefaults
    var refreshInterval: RefreshInterval {
        get {
            RefreshInterval(rawValue: UserDefaults.standard.integer(forKey: "refreshInterval"))
                ?? .minutes5
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "refreshInterval")
        }
    }

    var notificationEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "notificationEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "notificationEnabled") }
    }

    var notificationThreshold: Int {
        get {
            let val = UserDefaults.standard.integer(forKey: "notificationThreshold")
            return val > 0 ? val : 20
        }
        set { UserDefaults.standard.set(newValue, forKey: "notificationThreshold") }
    }

    var customExecutablePath: String {
        get { UserDefaults.standard.string(forKey: "customExecutablePath") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "customExecutablePath") }
    }

    var launchAtLogin: Bool {
        get { UserDefaults.standard.object(forKey: "launchAtLogin") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "launchAtLogin") }
    }
}
