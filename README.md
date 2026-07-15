# KiroMeter

macOS menu bar app that displays your Kiro credit usage percentage.

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

This is an unsigned build. On first launch, macOS Gatekeeper may block it:

1. Right-click the app → "Open"
2. Or: System Settings → Privacy & Security → "Open Anyway"

## License

MIT
