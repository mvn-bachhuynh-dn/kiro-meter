import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?

    private let settings = SettingsStore()
    private let viewModel = UsageViewModel()
    private let scheduler = RefreshScheduler()
    private let thresholdEvaluator = ThresholdEvaluator()
    private var observationTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        setupNotificationObservers()
        startObservingViewModel()

        // Ensure bare agent config exists for optimized CLI calls
        BareAgentEnsurer.ensureExists()

        // Launch at login
        LaunchAtLogin.sync(shouldEnable: settings.launchAtLogin)

        // Start scheduler
        startScheduler()

        // Initial fetch
        viewModel.refresh()
        scheduler.recordManualRefresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        observationTask?.cancel()
        scheduler.stop()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover)
        updateStatusItemDisplay()
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 300, height: 300)
        popover.contentViewController = NSHostingController(
            rootView: UsageDetailView(viewModel: viewModel)
        )
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettings),
            name: .openSettings,
            object: nil
        )
    }

    private func startScheduler() {
        scheduler.start(interval: settings.refreshInterval) { [weak self] in
            await self?.scheduledRefresh()
        }
    }

    // MARK: - Actions

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc private func openSettings() {
        if popover.isShown { popover.performClose(nil) }

        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(settings: settings)
        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "KiroMeter Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 420, height: 400))
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    // MARK: - Refresh & Notifications

    private func scheduledRefresh() async {
        await viewModel.performFetch()
        scheduler.recordManualRefresh()
        updateStatusItemDisplay()
        evaluateNotification()
    }

    private func evaluateNotification() {
        guard settings.notificationEnabled,
              let snapshot = viewModel.snapshot else { return }

        if thresholdEvaluator.shouldNotify(
            snapshot: snapshot,
            threshold: settings.notificationThreshold
        ) {
            thresholdEvaluator.markNotified()
            Task {
                let authorized = await NotificationClient.shared.isAuthorized()
                if !authorized {
                    let granted = await NotificationClient.shared.requestPermission()
                    guard granted else { return }
                }
                await NotificationClient.shared.sendLowCreditAlert(
                    remaining: snapshot.creditsRemaining,
                    total: snapshot.creditsTotal,
                    percent: snapshot.remainingPercent ?? 0
                )
            }
        }
    }

    // MARK: - Observation

    private func startObservingViewModel() {
        observationTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.updateStatusItemDisplay()
                self?.evaluateNotification()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    func updateStatusItemDisplay() {
        guard let button = statusItem?.button else { return }

        let label = StatusBarPresentation.menuBarLabel(for: viewModel.snapshot)
        let isCritical = StatusBarPresentation.isCriticalState(for: viewModel.snapshot)

        if isCritical {
            let attributed = NSMutableAttributedString(string: "⚠ \(label)")
            attributed.addAttributes(
                [.foregroundColor: NSColor.systemRed],
                range: NSRange(location: 0, length: attributed.length)
            )
            button.attributedTitle = attributed
            button.setAccessibilityLabel("KiroMeter: credits exhausted")
        } else {
            button.attributedTitle = NSAttributedString(string: "")
            button.title = label
            if let percent = viewModel.snapshot?.remainingPercent {
                button.setAccessibilityLabel("KiroMeter: \(Int(percent.rounded()))% credits remaining")
            } else {
                button.setAccessibilityLabel("KiroMeter: usage unavailable")
            }
        }
    }
}
