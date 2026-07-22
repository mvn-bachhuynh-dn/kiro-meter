import Foundation

/// Privacy-relevant settings parsed from kiro-cli configuration.
/// These indicate whether user data is being sent externally.
public struct PrivacySettings: Sendable, Equatable {
    /// Whether telemetry (usage metrics) is enabled.
    public let telemetryEnabled: Bool

    /// Whether prompt/code content is shared with AWS (prompt logging).
    public let promptLoggingEnabled: Bool

    /// True when both telemetry and prompt logging are disabled — maximum privacy.
    public var isFullyPrivate: Bool {
        !telemetryEnabled && !promptLoggingEnabled
    }
}
