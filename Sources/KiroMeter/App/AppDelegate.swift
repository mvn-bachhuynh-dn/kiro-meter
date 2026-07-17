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
    private let updateChecker = UpdateChecker()
    private var observationTask: Task<Void, Never>?
    private var outsideClickMonitor: Any?

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

        // Check for updates
        updateChecker.checkAutomaticallyIfNeeded()
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
        popover.behavior = .applicationDefined
        popover.contentSize = NSSize(width: 300, height: 300)
        popover.contentViewController = NSHostingController(
            rootView: UsageDetailView(viewModel: viewModel, updateChecker: updateChecker)
        )
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettings),
            name: .openSettings,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )

        // Sleep/wake resilience: closing the lid can wedge an in-flight
        // kiro-cli fetch (dead network socket after wake). Abort on sleep and
        // start a clean refresh on wake so the UI never gets stuck loading.
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        workspaceCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
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
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)

        // Dismiss when the user clicks anywhere outside the app (other apps,
        // desktop, Finder). Global monitors only fire for out-of-process events,
        // so clicking the status item itself is unaffected — avoiding the
        // re-toggle glitch that .transient behavior can cause.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    @objc private func appDidResignActive() {
        // Fires when switching to another app (e.g. Cmd-Tab).
        closePopover()
    }

    @objc private func systemWillSleep() {
        // Stop the timer and abort any in-flight fetch. Cancelling the scheduler
        // task propagates cancellation into a scheduled fetch (force-killing the
        // kiro-cli process); cancelInFlight() handles a manual refresh.
        scheduler.stop()
        viewModel.cancelInFlight()
    }

    @objc private func systemDidWake() {
        // Restart the timer and kick a fresh fetch now that networking is back.
        startScheduler()
        viewModel.refresh()
        scheduler.recordManualRefresh()
        updateStatusItemDisplay()
    }

    @objc private func openSettings() {
        if popover.isShown { closePopover() }

        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(settings: settings, updateChecker: updateChecker)
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
