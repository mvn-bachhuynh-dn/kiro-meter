import SwiftUI
import AppKit

struct SettingsView: View {
    @Bindable var settings: SettingsStore
    var updateChecker: UpdateChecker

    var body: some View {
        Form {
            refreshSection
            notificationSection
            executableSection
            loginSection
            updatesSection
            aboutSection
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 460)
        .padding()
    }

    // MARK: - Sections

    private var refreshSection: some View {
        Section("Refresh") {
            Picker("Auto-refresh interval", selection: Binding(
                get: { settings.refreshInterval },
                set: { settings.refreshInterval = $0 }
            )) {
                ForEach(RefreshInterval.allCases, id: \.rawValue) { interval in
                    Text(interval.label).tag(interval)
                }
            }
        }
    }

    private var notificationSection: some View {
        Section("Notifications") {
            Toggle("Enable low credit alerts", isOn: Binding(
                get: { settings.notificationEnabled },
                set: { settings.notificationEnabled = $0 }
            ))

            if settings.notificationEnabled {
                Stepper(
                    "Alert when below \(settings.notificationThreshold)%",
                    value: Binding(
                        get: { settings.notificationThreshold },
                        set: { settings.notificationThreshold = $0 }
                    ),
                    in: 1...50,
                    step: 5
                )
            }
        }
    }

    private var executableSection: some View {
        Section("Kiro CLI") {
            HStack {
                TextField(
                    "Path (leave empty for auto-detect)",
                    text: Binding(
                        get: { settings.customExecutablePath },
                        set: { settings.customExecutablePath = $0 }
                    )
                )
                .textFieldStyle(.roundedBorder)

                Button("Browse...") {
                    browseForExecutable()
                }
            }
            Text("Auto-detects from /Applications/Kiro CLI.app, ~/.local/bin, Homebrew")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var loginSection: some View {
        Section("System") {
            Toggle("Launch at login", isOn: Binding(
                get: { settings.launchAtLogin },
                set: { newValue in
                    settings.launchAtLogin = newValue
                    LaunchAtLogin.sync(shouldEnable: newValue)
                }
            ))
        }
    }

    private var updatesSection: some View {
        Section("Updates") {
            Toggle("Automatically check for updates", isOn: Binding(
                get: { updateChecker.autoCheckEnabled },
                set: { updateChecker.autoCheckEnabled = $0 }
            ))

            HStack {
                Button("Check for Updates") {
                    updateChecker.checkNow()
                }
                .disabled(updateChecker.state == .checking)

                Spacer()

                updateStatusView
            }

            if case let .updateAvailable(version, url) = updateChecker.state,
               let downloadURL = URL(string: url) {
                HStack {
                    Text("Version \(version) is available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Link("Download", destination: downloadURL)
                        .font(.caption)
                }
            }
        }
    }

    @ViewBuilder
    private var updateStatusView: some View {
        switch updateChecker.state {
        case .idle:
            EmptyView()
        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Checking…").font(.caption).foregroundStyle(.secondary)
            }
        case .upToDate:
            Label("Up to date", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .updateAvailable:
            Label("Update available", systemImage: "arrow.down.circle.fill")
                .font(.caption)
                .foregroundStyle(.blue)
        case let .failed(message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .lineLimit(1)
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("App", value: AppInfo.name)
            LabeledContent("Version", value: "\(AppInfo.version) (\(AppInfo.build))")
        }
    }

    // MARK: - Actions

    private func browseForExecutable() {
        let panel = NSOpenPanel()
        panel.title = "Select kiro-cli executable"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            settings.customExecutablePath = url.path
        }
    }
}
