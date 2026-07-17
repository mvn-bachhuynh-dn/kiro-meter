import Foundation

/// Single source of truth for app version information.
///
/// Reads from the app bundle's `Info.plist` when running as a bundled `.app`.
/// Falls back to `devFallbackVersion` when running via `swift run` (no bundle),
/// so the value stays sensible during development.
enum AppInfo {
    /// Used only when running outside an app bundle (e.g. `swift run`).
    /// Keep in sync with `CFBundleShortVersionString` in scripts/bundle.sh
    /// and .github/workflows/release.yml.
    static let devFallbackVersion = "1.1.3"

    static let name = "KiroMeter"

    /// Marketing version, e.g. "1.1.0". Reads `CFBundleShortVersionString`.
    static let version: String = {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? devFallbackVersion
    }()

    /// Build number, e.g. "1". Reads `CFBundleVersion`.
    static let build: String = {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "—"
    }()

    /// Version with a "v" prefix for display, e.g. "v1.1.0".
    static var displayVersion: String { "v\(version)" }
}
