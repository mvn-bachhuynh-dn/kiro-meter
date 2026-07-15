import AppKit

// KiroMeter - macOS menu bar app for Kiro credit usage monitoring.
// LSUIElement = true hides the app from the Dock.

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // No dock icon
app.run()
