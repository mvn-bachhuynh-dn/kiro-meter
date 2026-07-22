import SwiftUI

struct UsageDetailView: View {
    @Bindable var viewModel: UsageViewModel
    var updateChecker: UpdateChecker

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection

            // Update available banner
            if updateChecker.shouldShowUpdateBanner {
                updateBanner
            }

            // Account info section
            if let accountInfo = viewModel.accountInfo {
                Divider()
                accountSection(accountInfo)
            }

            // Privacy status section
            if let privacy = viewModel.privacySettings {
                Divider()
                privacySection(privacy)
            }

            Divider()
            if let snapshot = viewModel.snapshot {
                creditsSection(snapshot)
                if let bonus = StatusBarPresentation.bonusLabel(for: snapshot) {
                    Divider()
                    bonusSection(bonus)
                }
            } else if viewModel.lastError != nil {
                errorSection
            } else {
                loadingSection
            }

            // Stale data indicator
            if viewModel.isStale {
                Divider()
                staleWarningSection
            }

            Divider()
            footerSection
        }
        .padding(16)
        .frame(width: 280)
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack {
            if let snapshot = viewModel.snapshot {
                Text(StatusBarPresentation.displayPlanName(snapshot.planName))
                    .font(.headline)
            } else {
                Text("KiroMeter")
                    .font(.headline)
            }
            Spacer()
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private func creditsSection(_ snapshot: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Progress bar
            if let percent = snapshot.usedPercent {
                ProgressView(value: min(percent, 100), total: 100)
                    .tint(progressTint(for: snapshot))
            }

            // Credits used / total
            Text(StatusBarPresentation.creditsLabel(for: snapshot))
                .font(.subheadline)

            // Remaining
            HStack {
                Text(StatusBarPresentation.remainingLabel(for: snapshot))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let percent = snapshot.remainingPercent {
                    Text("\(Int(percent.rounded()))% left")
                        .font(.subheadline.bold())
                        .foregroundStyle(percentColor(for: snapshot))
                }
            }

            // Reset date
            if let resetLabel = StatusBarPresentation.resetLabel(for: snapshot) {
                Text(resetLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Last fetched time
            if let lastFetch = viewModel.lastFetchedAt {
                Text("Updated \(lastFetch, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func bonusSection(_ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Bonus Credits")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(label)
                .font(.caption)
        }
    }

    @ViewBuilder
    private func accountSection(_ account: AccountInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "person.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.caption)
                Text("Account")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            if let email = account.email {
                HStack(spacing: 4) {
                    Text(email)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            if let region = account.displayRegion {
                HStack(spacing: 4) {
                    Text("Region:")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(region)
                        .font(.caption2.monospaced())
                }
            }

            if let host = account.startURLHost {
                HStack(spacing: 4) {
                    Text("IdC:")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(host)
                        .font(.caption2.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }

    @ViewBuilder
    private func privacySection(_ privacy: PrivacySettings) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: privacyShieldIcon)
                    .foregroundStyle(privacyShieldColor)
                    .font(.caption)
                Text("Privacy")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            privacyRow(label: "Telemetry", enabled: privacy.telemetryEnabled,
                       info: "Usage metrics sent to AWS for analytics.")

            privacyRow(label: "Content Sharing", enabled: privacy.promptLoggingEnabled,
                       info: "Code snippets shared with AWS for service improvement. Only affects Free tier.")

            // Prompt Logging — from Kiro IDE logs
            promptLoggingRow
        }
    }

    /// Prompt Logging row with inline info button.
    @ViewBuilder
    private var promptLoggingRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text("Prompt Logging:")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                promptLoggingBadge
            }

            // Always show explanation text below the badge
            Text(promptLoggingDescription)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            // Guidance if IDE not available
            if !viewModel.isIDEAvailable {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 9))
                    Text("Install & open Kiro IDE once to detect")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.blue)
                .padding(.top, 1)
            } else if viewModel.enterprisePolicies == nil {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9))
                    Text("Reopen Kiro IDE to refresh status")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.blue)
                .padding(.top, 1)
            }
        }
    }

    /// Badge for prompt logging based on enterprise policies.
    @ViewBuilder
    private var promptLoggingBadge: some View {
        if let policies = viewModel.enterprisePolicies {
            privacyBadge(enabled: policies.promptLogging)
        } else {
            HStack(spacing: 2) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.caption2)
                Text("Unknown")
                    .font(.caption2.bold())
            }
            .foregroundStyle(.secondary)
        }
    }

    /// Description text for prompt logging status.
    private var promptLoggingDescription: String {
        if let policies = viewModel.enterprisePolicies {
            return policies.promptLogging
                ? "Admin has enabled logging. All your prompts and AI responses are recorded to an S3 bucket controlled by your organization."
                : "Admin prompt logging is off. Your prompts are not being recorded."
        }
        return "Detects if your admin logs all prompts & responses. Requires Kiro IDE to have been opened at least once."
    }

    /// A single privacy row with label, badge, and hover info.
    private func privacyRow(label: String, enabled: Bool, info: String) -> some View {
        HStack(spacing: 6) {
            Text("\(label):")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            privacyBadge(enabled: enabled)
        }
        .help(info)
    }

    /// Shield icon depends on overall privacy state including prompt logging.
    private var privacyShieldIcon: String {
        if let policies = viewModel.enterprisePolicies, policies.promptLogging {
            return "exclamationmark.shield.fill"
        }
        if let privacy = viewModel.privacySettings, !privacy.isFullyPrivate {
            return "exclamationmark.shield.fill"
        }
        return "lock.shield.fill"
    }

    /// Shield color depends on overall privacy state.
    private var privacyShieldColor: Color {
        if let policies = viewModel.enterprisePolicies, policies.promptLogging {
            return .red
        }
        if let privacy = viewModel.privacySettings, !privacy.isFullyPrivate {
            return .orange
        }
        return .green
    }

    private func privacyBadge(enabled: Bool) -> some View {
        HStack(spacing: 2) {
            Image(systemName: enabled ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.caption2)
            Text(enabled ? "ON" : "OFF")
                .font(.caption2.bold())
        }
        .foregroundStyle(enabled ? .orange : .green)
    }

    private var errorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text("Unable to fetch usage")
                    .font(.subheadline)
            }
            if let error = viewModel.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if let guidance = viewModel.errorGuidance {
                Text(guidance)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var loadingSection: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                ProgressView()
                Text("Fetching usage...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var staleWarningSection: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(.orange)
                .font(.caption)
            VStack(alignment: .leading, spacing: 2) {
                Text("Showing cached data")
                    .font(.caption)
                    .foregroundStyle(.orange)
                if let error = viewModel.lastError {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }

    private var footerSection: some View {
        HStack {
            Button("Refresh") {
                viewModel.refresh()
            }
            .disabled(viewModel.isLoading)

            Spacer()

            Text(AppInfo.displayVersion)
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Button {
                NotificationCenter.default.post(name: .openSettings, object: nil)
            } label: {
                Image(systemName: "gear")
            }
            .buttonStyle(.borderless)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .controlSize(.small)
    }

    private var updateBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.blue)
                .font(.body)
            VStack(alignment: .leading, spacing: 2) {
                Text("v\(updateChecker.availableVersion ?? "") available")
                    .font(.caption.bold())
                if let url = updateChecker.availableURL,
                   let downloadURL = URL(string: url) {
                    Link("Download", destination: downloadURL)
                        .font(.caption)
                }
            }
            Spacer()
            Button {
                updateChecker.dismissBanner()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.borderless)
            .help("Dismiss this update")
        }
        .padding(8)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Helpers

    private func progressTint(for snapshot: UsageSnapshot) -> Color {
        if snapshot.isCritical { return .red }
        guard let remaining = snapshot.remainingPercent else { return .blue }
        if remaining <= 10 { return .red }
        if remaining <= 25 { return .orange }
        return .blue
    }

    private func percentColor(for snapshot: UsageSnapshot) -> Color {
        if snapshot.isCritical { return .red }
        guard let remaining = snapshot.remainingPercent else { return .primary }
        if remaining <= 10 { return .red }
        if remaining <= 25 { return .orange }
        return .green
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("KiroMeter.openSettings")
}
