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
