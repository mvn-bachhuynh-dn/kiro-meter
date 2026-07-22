import Foundation

/// Represents the current Kiro account identity and connection details.
public struct AccountInfo: Sendable, Equatable {
    public let email: String?
    public let startURL: String?
    public let region: String?
    public let profileName: String?
    public let profileARN: String?

    /// Short display for the region (e.g. "us-east-1").
    public var displayRegion: String? {
        region
    }

    /// Short host portion of the start URL (e.g. "d-90660851ca.awsapps.com").
    public var startURLHost: String? {
        guard let startURL, let url = URL(string: startURL) else { return nil }
        return url.host
    }
}
