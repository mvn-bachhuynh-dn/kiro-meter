# macOS / AppKit Gotchas

Hard-won lessons specific to this menu-bar app. Read before touching the popover,
distribution, or launch behavior.

## Popover dismissal (NSPopover from a status item)

Requirements: the popover must close when the user (a) clicks the status item
again, (b) switches to another app, or (c) clicks anywhere outside the app.

- Do NOT rely on `.transient` alone: clicking the status item while shown can
  trigger a dismiss-then-reopen "double toggle" that looks like a position glitch.
- Current approach (in `AppDelegate`):
  - `popover.behavior = .applicationDefined` (we control closing).
  - On show: install `NSEvent.addGlobalMonitorForEvents([.leftMouseDown,
    .rightMouseDown])` → close on any out-of-process click. Global monitors do
    NOT fire for in-app events, so clicking the status item is unaffected (no
    double toggle).
  - Also observe `NSApplication.didResignActiveNotification` → close on Cmd-Tab.
  - On close: `NSEvent.removeMonitor(...)` and clear the stored monitor.
- `NSApp.activate(ignoringOtherApps: true)` when showing so the popover takes key.

## Unsigned distribution

The app is unsigned / not notarized. macOS quarantines downloads and Gatekeeper
blocks first launch ("damaged" / "unidentified developer").

- Users must run `xattr -cr /Applications/KiroMeter.app` once after install.
- `scripts/install.sh` automates download → install → `xattr -cr` → launch, with
  a `sudo` fallback if `/Applications` isn't writable and quitting any running
  instance first. Keep that flow intact.
- If the app ever gets code signing + notarization, revisit: you could then adopt
  Sparkle for true in-app auto-update (needs a signed appcast feed). Until then,
  keep the lightweight GitHub-Releases `UpdateChecker` (detect + open download).

## Menu bar accessory basics

- `LSUIElement = true` in Info.plist → no Dock icon, no default main window.
- There is no main window to fall back on; Settings is created on demand as an
  `NSWindow` with `isReleasedWhenClosed = false` and reused.
- GUI apps don't source `.zshrc` — resolve `kiro-cli` via `ExecutableResolver`,
  never assume shell aliases or PATH from an interactive shell.
