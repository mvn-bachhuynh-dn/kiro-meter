import Foundation

/// Privacy-relevant settings parsed from kiro-cli configuration.
/// These indicate whether user data is being sent externally.
///
/// Note: There are two layers of "prompt logging":
/// 1. **Client-side content sharing** (`codeWhisperer.shareCodeWhispererContentWithAWS`)
///    — user opt-in to share code snippets with AWS. Detectable locally.
/// 2. **Admin-level prompt logging** (Kiro Admin console)
///    — org admin enables logging of all prompts/responses. NOT detectable from client.
public struct PrivacySettings: Sendable, Equatable {
    /// Whether telemetry (usage metrics) is enabled.
    public let telemetryEnabled: Bool

    /// Whether client-side content sharing with AWS is enabled.
    /// This is the local `codeWhisperer.shareCodeWhispererContentWithAWS` setting.
    /// Note: This does NOT reflect admin-level prompt logging.
    public let promptLoggingEnabled: Bool

    /// True when both telemetry and content sharing are disabled — maximum local privacy.
    /// Admin-level prompt logging cannot be checked from the client.
    public var isFullyPrivate: Bool {
        !telemetryEnabled && !promptLoggingEnabled
    }
}
