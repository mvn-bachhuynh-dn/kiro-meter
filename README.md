# KiroMeter

macOS menu bar app that displays your Kiro credit usage percentage.

<img width="289" height="259" alt="image" src="https://github.com/user-attachments/assets/0b0e0509-1d51-4961-be53-8b72b6ddaaed" />

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)

## Features

- **Menu bar display** — Shows remaining credit percentage (e.g., "85%")
- **Click for details** — Plan name, credits used/total/remaining, reset date, bonus credits
- **Account info** — Email, region, and Identity Center start URL
- **Privacy monitor** — Real-time status of telemetry, content sharing, and admin prompt logging
- **Prompt Logging detection** — Detects if your org admin has enabled prompt logging (requires Kiro IDE)
- **Auto-refresh** — Configurable interval: 1, 5, 15, or 30 minutes
- **Notifications** — Alert when credits drop below configurable threshold
- **Critical state** — Red warning icon when credits are exhausted
- **Launch at login** — Starts automatically with macOS
- **Error resilience** — Keeps last-known-good data, shows clear guidance on errors

## Prerequisites

1. **Kiro CLI** installed — [Download from kiro.dev](https://kiro.dev)
2. **Logged in** — Run `kiro-cli login` in Terminal
3. *(Optional)* **Kiro IDE** installed — Enables admin Prompt Logging detection

The app auto-detects `kiro-cli` at:
- `/Applications/Kiro CLI.app/Contents/MacOS/kiro-cli`
- `~/.local/bin/kiro-cli`
- Homebrew (`/opt/homebrew/bin/`, `/usr/local/bin/`)

You can also set a custom path in Settings.

## Download & Install (no build required)

Most users don't need to build from source — just grab the latest release.

### Option A — One command (recommended)

Paste this into Terminal. It downloads the latest release, installs it to
`/Applications`, removes the quarantine flag, and launches the app:

```bash
curl -fsSL https://raw.githubusercontent.com/mvn-bachhuynh-dn/kiro-meter/main/scripts/install.sh | bash
```

> Piping a script into `bash` runs it immediately. If you'd rather inspect it
> first, open [`scripts/install.sh`](scripts/install.sh), or download and run it
> manually:
>
> ```bash
> curl -fsSLO https://raw.githubusercontent.com/mvn-bachhuynh-dn/kiro-meter/main/scripts/install.sh
> bash install.sh
> ```

Re-running the script also **updates** KiroMeter to the latest release.

### Option B — Manual

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
update is available it shows a banner with a download link.

Since the app is unsigned, updating is manual. The easiest way is to re-run the
install script, which grabs the latest release and replaces the app:

```bash
curl -fsSL https://raw.githubusercontent.com/mvn-bachhuynh-dn/kiro-meter/main/scripts/install.sh | bash
```

Or do it by hand: download the new release, replace the app in `/Applications`,
and run `xattr -cr /Applications/KiroMeter.app` again.

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

## Privacy & Security Monitor

KiroMeter shows the privacy status of your Kiro account in the popover:

| Setting | Source | What it means |
|---------|--------|---------------|
| **Telemetry** | `kiro-cli settings` | Usage metrics sent to AWS |
| **Content Sharing** | `kiro-cli settings` | Code snippets shared for service improvement (Free tier only) |
| **Prompt Logging** | Kiro IDE logs | Admin-level: all prompts & responses logged to org S3 bucket |

### Prompt Logging detection

This is the most important privacy indicator. When your org admin enables Prompt
Logging on the Kiro Admin console, **all your prompts and AI responses are recorded**.

KiroMeter detects this by reading the Kiro IDE's `EnterpriseSettingsManager` log:

```
~/Library/Application Support/Kiro/logs/<session>/window*/exthost/kiro.kiroAgent/Kiro Logs.log
```

**Requirements:**
- Kiro IDE must be installed and opened at least once (to generate log files)
- After admin changes the setting, reopen Kiro IDE to refresh the status

**Status indicators:**
- 🟢 **OFF** — Prompt logging is disabled, your prompts are not recorded
- 🟠 **ON** — Your prompts ARE being logged to your org's S3 bucket
- 🔘 **Unknown** — Kiro IDE not found; install and open it once to detect

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
│   ├── UsageService (actor)
│   │   ├── ExecutableResolver (finds kiro-cli)
│   │   ├── CLIRunner (async process with timeout)
│   │   └── UsageParser (regex-based output parser)
│   └── AccountService (actor)
│       ├── AccountParser (parses whoami + settings JSON)
│       └── IDELogParser (reads Kiro IDE logs for enterprise policies)
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
