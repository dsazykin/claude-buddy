import AppKit
import ServiceManagement

/// Menu bar item and the menu shared with the character's right-click.
final class StatusItemController: NSObject, NSMenuDelegate {
    let menu = NSMenu()

    private let controller: BuddyController
    private let preferences: Preferences
    private let statusItem: NSStatusItem

    private var watchItem: NSMenuItem!
    private var followItem: NSMenuItem!
    private var reactItem: NSMenuItem!
    private var clickThroughItem: NSMenuItem!
    private var visibleItem: NSMenuItem!
    private var loginItem: NSMenuItem!
    private var sizeItems: [BuddySize: NSMenuItem] = [:]
    private var layerItems: [BuddyLayer: NSMenuItem] = [:]

    init(controller: BuddyController, preferences: Preferences) {
        self.controller = controller
        self.preferences = preferences
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        statusItem.button?.image = StatusItemController.sparkleImage()
        statusItem.button?.toolTip = "Claude Buddy"
        buildMenu()
        statusItem.menu = menu
    }

    // MARK: - Menu construction

    private func buildMenu() {
        menu.delegate = self
        // We drive the enabled/checked state ourselves in menuNeedsUpdate.
        menu.autoenablesItems = false

        menu.addItem(item("Say Something", #selector(saySomething)))
        menu.addItem(.separator())

        watchItem = item("Watch The Cursor", #selector(toggleWatch))
        followItem = item("Follow The Cursor", #selector(toggleFollow))
        reactItem = item("React To Claude Code", #selector(toggleReact))
        clickThroughItem = item("Click Through Him", #selector(toggleClickThrough))
        [watchItem, followItem, reactItem, clickThroughItem].forEach { menu.addItem($0!) }
        menu.addItem(.separator())

        let sizeMenu = NSMenu()
        for size in BuddySize.allCases {
            let entry = item(size.title, #selector(changeSize))
            entry.representedObject = size.rawValue
            sizeItems[size] = entry
            sizeMenu.addItem(entry)
        }
        let sizeParent = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        sizeParent.submenu = sizeMenu
        menu.addItem(sizeParent)

        let layerMenu = NSMenu()
        for layer in BuddyLayer.allCases {
            let entry = item(layer.title, #selector(changeLayer))
            entry.representedObject = layer.rawValue
            layerItems[layer] = entry
            layerMenu.addItem(entry)
        }
        let layerParent = NSMenuItem(title: "Layer", action: nil, keyEquivalent: "")
        layerParent.submenu = layerMenu
        menu.addItem(layerParent)
        menu.addItem(.separator())

        visibleItem = item("Show Buddy", #selector(toggleVisible))
        menu.addItem(visibleItem)
        menu.addItem(item("Reset Position", #selector(resetPosition)))
        menu.addItem(item("Edit Quips…", #selector(editQuips)))

        loginItem = item("Launch At Login", #selector(toggleLaunchAtLogin))
        menu.addItem(loginItem)
        menu.addItem(.separator())

        let quit = item("Quit Claude Buddy", #selector(quit))
        quit.keyEquivalent = "q"
        menu.addItem(quit)
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self
        return entry
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshStates()
    }

    private func refreshStates() {
        watchItem.state = preferences.watchCursor ? .on : .off
        followItem.state = preferences.followCursor ? .on : .off
        reactItem.state = preferences.reactToClaude ? .on : .off
        clickThroughItem.state = preferences.clickThrough ? .on : .off
        visibleItem.state = preferences.visible ? .on : .off

        // Following only means anything if he can see the cursor at all.
        followItem.isEnabled = preferences.watchCursor

        for (size, entry) in sizeItems {
            entry.state = preferences.size == size ? .on : .off
        }
        for (layer, entry) in layerItems {
            entry.state = preferences.layer == layer ? .on : .off
        }
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    // MARK: - Actions

    @objc private func saySomething() { controller.speakRandomly() }
    @objc private func toggleWatch() { preferences.watchCursor.toggle() }
    @objc private func toggleFollow() { preferences.followCursor.toggle() }
    @objc private func toggleReact() { preferences.reactToClaude.toggle() }
    @objc private func toggleClickThrough() { preferences.clickThrough.toggle() }
    @objc private func toggleVisible() { preferences.visible.toggle() }
    @objc private func resetPosition() { controller.resetPosition() }

    @objc private func changeSize(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let size = BuddySize(rawValue: raw) else { return }
        preferences.size = size
    }

    @objc private func changeLayer(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let layer = BuddyLayer(rawValue: raw) else { return }
        preferences.layer = layer
    }

    @objc private func editQuips() {
        let url = QuipLibrary.shared.ensureFileExists()
        NSWorkspace.shared.open(url)
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            presentLoginItemError(error)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func presentLoginItemError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Couldn't change the login item"
        alert.informativeText = """
        \(error.localizedDescription)

        Login items only work for a real app bundle. Run Scripts/build-app.sh \
        and launch ClaudeBuddy.app instead of `swift run`.
        """
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    // MARK: - Icon

    /// Four-pointed sparkle, drawn as a template so it follows the menu bar.
    private static func sparkleImage() -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size, flipped: false) { rect in
            let centre = CGPoint(x: rect.midX, y: rect.midY)
            let outer = min(rect.width, rect.height) / 2 - 0.5
            let inner = outer * 0.30

            let path = NSBezierPath()
            for step in 0..<8 {
                let radius = step.isMultiple(of: 2) ? outer : inner
                let angle = Double(step) * .pi / 4
                let point = NSPoint(x: centre.x + CGFloat(cos(angle)) * radius,
                                    y: centre.y + CGFloat(sin(angle)) * radius)
                if step == 0 {
                    path.move(to: point)
                } else {
                    path.line(to: point)
                }
            }
            path.close()
            NSColor.black.setFill()
            path.fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
