import Foundation

/// Checks GitHub releases for new versions of KiroMeter.
@MainActor
@Observable
final class UpdateChecker {
    static let currentVersion = "1.1.0"
    private static let repoOwner = "mvn-bachhuynh-dn"
    private static let repoName = "kiro-meter"
    private static let checkInterval: TimeInterval = 6 * 3600 // 6 hours

    var latestVersion: String?
    var downloadURL: String?
    var isUpdateAvailable: Bool { latestVersion != nil && latestVersion != Self.currentVersion && isNewer(latestVersion!) }

    private var lastCheckDate: Date? {
        get { UserDefaults.standard.object(forKey: "lastUpdateCheck") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "lastUpdateCheck") }
    }

    var dismissedVersion: String? {
        get { UserDefaults.standard.string(forKey: "dismissedUpdateVersion") }
        set { UserDefaults.standard.set(newValue, forKey: "dismissedUpdateVersion") }
    }

    /// Whether to show the update banner (not dismissed for this version).
    var shouldShowUpdateBanner: Bool {
        isUpdateAvailable && latestVersion != dismissedVersion
    }

    /// Check for updates if enough time has passed since last check.
    func checkIfNeeded() {
        if let last = lastCheckDate, Date().timeIntervalSince(last) < Self.checkInterval {
            return
        }
        check()
    }

    /// Force check for updates now.
    func check() {
        Task {
            await performCheck()
        }
    }

    private func performCheck() async {
        let urlString = "https://api.github.com/repos/\(Self.repoOwner)/\(Self.repoName)/releases/latest"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let tagVersion = release.tagName.hasPrefix("v")
                ? String(release.tagName.dropFirst())
                : release.tagName

            lastCheckDate = Date()
            latestVersion = tagVersion
            downloadURL = release.htmlURL
        } catch {
            // Silently fail — update check is non-critical
        }
    }

    /// Compare semantic versions: returns true if `version` is newer than current.
    private func isNewer(_ version: String) -> Bool {
        let current = Self.currentVersion.split(separator: ".").compactMap { Int($0) }
        let remote = version.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(current.count, remote.count) {
            let c = i < current.count ? current[i] : 0
            let r = i < remote.count ? remote[i] : 0
            if r > c { return true }
            if r < c { return false }
        }
        return false
    }

    func dismiss() {
        dismissedVersion = latestVersion
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
