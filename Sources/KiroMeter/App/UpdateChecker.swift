import Foundation

/// Checks GitHub releases for new versions of KiroMeter.
///
/// This is a lightweight, GitHub-Releases-based updater suitable for an
/// unsigned app. It detects newer versions and points the user to the
/// download page. (For true in-app auto-install you'd migrate to Sparkle,
/// which requires code signing + notarization + a signed appcast feed.)
@MainActor
@Observable
final class UpdateChecker {
    private static let repoOwner = "mvn-bachhuynh-dn"
    private static let repoName = "kiro-meter"
    private static let autoCheckInterval: TimeInterval = 6 * 3600 // 6 hours

    /// The version this build reports (single source of truth).
    static var currentVersion: String { AppInfo.version }

    /// Update-check lifecycle state.
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case updateAvailable(version: String, url: String)
        case failed(String)
    }

    private(set) var state: State = .idle

    // MARK: - Persisted settings

    /// Whether background auto-checking is enabled.
    var autoCheckEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "autoCheckUpdates") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "autoCheckUpdates") }
    }

    private var lastCheckDate: Date? {
        get { UserDefaults.standard.object(forKey: "lastUpdateCheck") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "lastUpdateCheck") }
    }

    private var dismissedVersion: String? {
        get { UserDefaults.standard.string(forKey: "dismissedUpdateVersion") }
        set { UserDefaults.standard.set(newValue, forKey: "dismissedUpdateVersion") }
    }

    // MARK: - Derived

    /// The available newer version, if any.
    var availableVersion: String? {
        if case let .updateAvailable(version, _) = state { return version }
        return nil
    }

    /// The download URL for the available update, if any.
    var availableURL: String? {
        if case let .updateAvailable(_, url) = state { return url }
        return nil
    }

    /// Whether to show the update banner in the popover (available and not dismissed).
    var shouldShowUpdateBanner: Bool {
        guard let version = availableVersion else { return false }
        return version != dismissedVersion
    }

    // MARK: - Public API

    /// Background check honoring the auto-check toggle and interval throttle.
    func checkAutomaticallyIfNeeded() {
        guard autoCheckEnabled else { return }
        if let last = lastCheckDate, Date().timeIntervalSince(last) < Self.autoCheckInterval {
            return
        }
        Task { await performCheck(manual: false) }
    }

    /// Manual "Check for Updates" — always runs, ignores throttle.
    func checkNow() {
        Task { await performCheck(manual: true) }
    }

    /// Dismiss the banner for the currently available version.
    func dismissBanner() {
        dismissedVersion = availableVersion
    }

    // MARK: - Implementation

    private func performCheck(manual: Bool) async {
        state = .checking

        let urlString = "https://api.github.com/repos/\(Self.repoOwner)/\(Self.repoName)/releases/latest"
        guard let url = URL(string: urlString) else {
            state = .failed("Invalid update URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                state = .failed("No response from GitHub")
                return
            }
            guard httpResponse.statusCode == 200 else {
                state = .failed("GitHub returned \(httpResponse.statusCode)")
                return
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let remoteVersion = Self.normalize(release.tagName)

            lastCheckDate = Date()

            if Self.isNewer(remoteVersion, than: Self.currentVersion) {
                state = .updateAvailable(version: remoteVersion, url: release.htmlURL)
            } else {
                state = .upToDate
            }
        } catch {
            state = .failed(manual ? error.localizedDescription : "Update check failed")
        }
    }

    /// Strip a leading "v" from a tag name (e.g. "v1.2.0" -> "1.2.0").
    private static func normalize(_ tag: String) -> String {
        tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }

    /// Semantic version comparison: is `lhs` strictly newer than `rhs`?
    static func isNewer(_ lhs: String, than rhs: String) -> Bool {
        let a = lhs.split(separator: ".").compactMap { Int($0) }
        let b = rhs.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(a.count, b.count) {
            let l = i < a.count ? a[i] : 0
            let r = i < b.count ? b[i] : 0
            if l > r { return true }
            if l < r { return false }
        }
        return false
    }
}

// MARK: - GitHub API Model

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}
