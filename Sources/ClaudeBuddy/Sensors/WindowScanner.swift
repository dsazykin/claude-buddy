import AppKit
import CoreGraphics

/// The top edge of somebody else's window: a ledge he can stand on.
struct Ledge {
    let windowID: CGWindowID
    let owner: String
    /// The window's frame in AppKit screen coordinates (origin bottom-left).
    let frame: CGRect

    /// The line his feet rest on.
    var topEdge: CGFloat { frame.maxY }
}

/// Finds ordinary app windows to stand on.
///
/// Reads the window list for bounds only — no window titles and no images — so
/// this needs no Screen Recording permission.
enum WindowScanner {

    /// Windows big enough to stand on, frontmost first.
    static func ledges(excluding pid: pid_t) -> [Ledge] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let entries = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        return entries.compactMap { ledge(from: $0, excluding: pid) }
    }

    /// Re-reads one window, so he can ride it when it moves. Returns nil once
    /// the window is closed, minimised or hidden behind a Space switch.
    static func ledge(for id: CGWindowID, excluding pid: pid_t) -> Ledge? {
        let entries = CGWindowListCreateDescriptionFromArray([id] as CFArray) as? [[String: Any]] ?? []
        guard let entry = entries.first else { return nil }
        // A window that has gone off-screen keeps its entry but stops being
        // listed as on-screen.
        guard entry[kCGWindowIsOnscreen as String] as? Bool == true else { return nil }
        return ledge(from: entry, excluding: pid)
    }

    // MARK: - Private

    /// Smallest window worth standing on. Below this he looks like he is
    /// balancing on a tooltip.
    private static let minimumSize = CGSize(width: 260, height: 140)

    private static func ledge(from entry: [String: Any], excluding pid: pid_t) -> Ledge? {
        // Layer 0 is an ordinary document window. Menu bar, Dock, notifications
        // and the wallpaper all live on other layers.
        guard entry[kCGWindowLayer as String] as? Int == 0,
              (entry[kCGWindowAlpha as String] as? Double ?? 1) > 0.1,
              entry[kCGWindowOwnerPID as String] as? pid_t != pid,
              let id = entry[kCGWindowNumber as String] as? CGWindowID,
              let bounds = entry[kCGWindowBounds as String] as? NSDictionary,
              let rect = CGRect(dictionaryRepresentation: bounds) else { return nil }

        guard rect.width >= minimumSize.width, rect.height >= minimumSize.height,
              let frame = appKitFrame(from: rect) else { return nil }

        let owner = entry[kCGWindowOwnerName as String] as? String ?? ""
        return Ledge(windowID: id, owner: owner, frame: frame)
    }

    /// The window list is measured from the top-left of the primary display;
    /// AppKit measures from its bottom-left.
    private static func appKitFrame(from rect: CGRect) -> CGRect? {
        guard let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero })
            ?? NSScreen.screens.first else { return nil }
        return CGRect(x: rect.minX,
                      y: primary.frame.height - rect.maxY,
                      width: rect.width,
                      height: rect.height)
    }
}
