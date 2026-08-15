import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: BuddyController?
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let preferences = Preferences.shared
        let controller = BuddyController(preferences: preferences)
        let statusItem = StatusItemController(controller: controller, preferences: preferences)

        controller.contextMenu = { [weak statusItem] in statusItem?.menu }
        controller.start()

        self.controller = controller
        self.statusItem = statusItem

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    @objc private func screenParametersChanged() {
        controller?.reclampPosition()
    }
}
