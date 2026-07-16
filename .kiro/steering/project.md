# KiroMeter — Project Guide

macOS menu bar app (Swift 6 / SwiftUI + AppKit) that shows Kiro credit usage.
It shells out to `kiro-cli chat --classic --no-interactive --agent bare "/usage"`,
parses the output, and displays the remaining percentage in the menu bar.

## Build / Run / Test

Requires Xcode.app installed (for SDK frameworks). Use the Makefile:

- `make build` — `swift build`
- `make test`  — `swift test --enable-swift-testing --disable-xctest`
- `make run`   — bundles and opens the `.app`
- `make bundle`— builds `.build/debug/KiroMeter.app` via `scripts/bundle.sh`
- `make clean`

Always run `make build` after code changes before claiming success.

> Note: local `make test` may fail with `no such module 'Testing'` if the local
> toolchain lacks Swift Testing. This is an environment issue, not a code error.
> CI (macos-15 + Xcode 16) runs tests with `continue-on-error`.

## Layout (Sources/KiroMeter/)

- `App/` — `AppDelegate` (status item, popover, wiring), `UsageViewModel`,
  `UpdateChecker`, `AppInfo` (version source of truth)
- `Views/` — `UsageDetailView` (popover), `SettingsView`
- `CLI/` — `UsageService` (actor), `CLIRunner`, `ExecutableResolver`, `BareAgentEnsurer`
- `Parser/` — `UsageParser` (regex, strips ANSI)
- `Settings/` — `SettingsStore` (UserDefaults), `RefreshScheduler`, `LaunchAtLogin`
- `Notifications/` — `NotificationClient`, `ThresholdEvaluator`
- `Models/` — `UsageSnapshot`, `StatusBarPresentation`

## Conventions

- App is a menu bar accessory (`LSUIElement = true`), no Dock icon / main window.
- UI/state types are `@MainActor`; `UsageService` is an `actor`.
- The app never stores credentials — auth is handled entirely by `kiro-cli`.
- GUI apps do not load `.zshrc`, so never rely on shell aliases; resolve the
  `kiro-cli` binary via `ExecutableResolver` (or the custom path in Settings).
- Keep last-known-good data on fetch failure; show guidance instead of blanking.
- Match existing SwiftUI patterns (`@Observable`, `@Bindable`) already in the repo.
