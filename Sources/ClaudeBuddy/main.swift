import AppKit

// Claude Buddy runs as a menu bar accessory: no Dock icon, no main menu window.
// Using a plain AppKit entry point (rather than SwiftUI's `App`) keeps this
// buildable as a SwiftPM executable without an Xcode project.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
