import Foundation

/// Enterprise policies fetched from Kiro IDE's EnterpriseSettingsManager log.
/// These reflect admin-level (org) settings that cannot be changed by the user.
///
/// Source: `~/Library/Application Support/Kiro/logs/<session>/window*/exthost/kiro.kiroAgent/Kiro Logs.log`
/// Pattern: `[EnterpriseSettingsManager] Enterprise mode enabled {"policies":{...}}`
public struct EnterprisePolicies: Sendable, Equatable {
    /// Whether admin-level prompt logging is enabled (prompts + responses logged to org S3 bucket).
    public let promptLogging: Bool

    /// Whether usage analytics collection is enabled at org level.
    public let usageAnalytics: Bool

    /// Whether content collection (code sharing for service improvement) is enabled at org level.
    public let contentCollection: Bool

    /// Whether MCP (Model Context Protocol) is enabled for the org.
    public let mcpEnabled: Bool

    /// Whether web tools are enabled for the org.
    public let webToolsEnabled: Bool

    /// Whether code reference tracker is enabled.
    public let codeReferenceTracker: Bool

    /// Timestamp when these policies were last read from the IDE log.
    public let fetchedAt: Date
}
