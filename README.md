# KiroMeter

macOS menu bar app that displays your Kiro credit usage percentage.
<img width="289" height="259" alt="image" src="https://github.com/user-attachments/assets/0b0e0509-1d51-4961-be53-8b72b6ddaaed" />

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)

## Features

- **Menu bar display** — Shows remaining credit percentage (e.g., "85%")
- **Click for details** — Plan name, credits used/total/remaining, reset date, bonus credits
- **Auto-refresh** — Configurable interval: 1, 5, 15, or 30 minutes
- **Notifications** — Alert when credits drop below configurable threshold
- **Critical state** — Red warning icon when credits are exhausted
- **Launch at login** — Starts automatically with macOS
- **Error resilience** — Keeps last-known-good data, shows clear guidance on errors

## Prerequisites

1. **Kiro CLI** installed — [Download from kiro.dev](https://kiro.dev)
2. **Logged in** — Run `kiro-cli login` in Terminal

The app auto-detects `kiro-cli` at:
- `/Applications/Kiro CLI.app/Contents/MacOS/kiro-cli`
- `~/.local/bin/kiro-cli`
- Homebrew (`/opt/homebrew/bin/`, `/usr/local/bin/`)

You can also set a custom path in Settings.

## Download & Install (no build required)

Most users don't need to build from source — just grab the latest release:

1. Go to the [**Releases** page](https://github.com/mvn-bachhuynh-dn/kiro-meter/releases/latest)
2. Download `KiroMeter-macOS.zip`
3. Unzip it and move `KiroMeter.app` to your `/Applications` folder
4. **Remove the quarantine flag** (required — see below), then open the app:

```bash
xattr -cr /Applications/KiroMeter.app
open /Applications/KiroMeter.app
```

### Why the `xattr` command?

KiroMeter is an **unsigned** app (not notarized by Apple). When you download it,
macOS adds a `com.apple.quarantine` attribute, and Gatekeeper will refuse to open
it with a message like *"KiroMeter is damaged and can't be opened"* or
*"cannot be opened because the developer cannot be verified"*.

The command below strips that quarantine attribute so the app can launch:

```bash
xattr -cr /Applications/KiroMeter.app
```

- `-c` clears extended attributes
- `-r` applies it recursively to everything inside the app bundle

This is safe — it only removes the download quarantine marker. You only need to
run it once, right after moving the app to `/Applications`.

> **Alternative (no Terminal):** Right-click the app → **Open** → **Open** in the
> dialog. If macOS still blocks it, use the `xattr` command above.

### Updating

KiroMeter checks GitHub for new versions automatically (toggleable in Settings →
Updates) and can check on demand via **Settings → Check for Updates**. When an
update is available it shows a banner with a download link. Since the app is
unsigned, updating is manual: download the new release, replace the app in
`/Applications`, and run `xattr -cr /Applications/KiroMeter.app` again.

## Build & Run

```bash
# Build
make build

# Run
make run

# Run tests
make test
```

> **Note:** Requires Xcode.app installed (for SDK frameworks).

## How It Works

KiroMeter calls `kiro-cli chat --classic --no-interactive --agent bare "/usage"` to fetch your usage data, parses the output (stripping ANSI codes), and displays the remaining percentage on your menu bar.

It does NOT:
- Use shell aliases (GUI apps don't load `.zshrc`)
- Require network access beyond what `kiro-cli` needs
- Store any credentials (authentication is handled by `kiro-cli`)

## Architecture

```
NSStatusItem (menu bar) → NSPopover (SwiftUI detail view)
                        → Settings window
AppDelegate
├── UsageViewModel (@MainActor, @Observable)
│   └── UsageService (actor)
│       ├── ExecutableResolver (finds kiro-cli)
│       ├── CLIRunner (async process with timeout)
│       └── UsageParser (regex-based output parser)
├── RefreshScheduler (periodic timer)
├── ThresholdEvaluator → NotificationClient
└── SettingsStore (UserDefaults)
```

## Unsigned Build Warning

KiroMeter is unsigned, so macOS Gatekeeper blocks it on first launch. See
[Why the `xattr` command?](#why-the-xattr-command) above for how to run:

```bash
xattr -cr /Applications/KiroMeter.app
```

Alternatively: right-click the app → **Open**, or go to System Settings →
Privacy & Security → **Open Anyway**.

## License

MIT
