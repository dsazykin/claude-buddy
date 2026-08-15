import AppKit

enum BuddySize: String, CaseIterable {
    case small, medium, large

    /// Deliberately small: he is a desk pet loitering at the edge of the screen,
    /// not a window. Medium puts him at roughly 66 x 72 points.
    var scale: CGFloat {
        switch self {
        case .small: return 0.36
        case .medium: return 0.50
        case .large: return 0.68
        }
    }

    var title: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
}

enum BuddyLayer: String, CaseIterable {
    /// Floats above ordinary windows.
    case floating
    /// Sits on the desktop, behind everything else.
    case desktop

    var title: String {
        switch self {
        case .floating: return "Float Above Windows"
        case .desktop: return "Sit On The Desktop"
        }
    }

    var windowLevel: NSWindow.Level {
        switch self {
        case .floating:
            return .floating
        case .desktop:
            // One notch above the desktop icons so he is never buried by the
            // wallpaper, but still behind every real window.
            return NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        }
    }
}

/// UserDefaults-backed settings. `onChange` fires after any mutation so the
/// controller can re-apply window state without a Combine dependency.
final class Preferences {
    static let shared = Preferences()

    var onChange: (() -> Void)?

    private let defaults = UserDefaults.standard

    private enum Key {
        static let watchCursor = "watchCursor"
        static let followCursor = "followCursor"
        static let hangOut = "hangOut"
        static let reactToClaude = "reactToClaude"
        static let clickThrough = "clickThrough"
        static let visible = "visible"
        static let size = "size"
        static let layer = "layer"
        static let positionX = "positionX"
        static let positionY = "positionY"
        static let hasPosition = "hasPosition"
        static let sleepAfterMinutes = "sleepAfterMinutes"
    }

    private init() {
        defaults.register(defaults: [
            Key.watchCursor: true,
            Key.followCursor: false,
            Key.hangOut: true,
            Key.reactToClaude: true,
            Key.clickThrough: false,
            Key.visible: true,
            Key.size: BuddySize.medium.rawValue,
            Key.layer: BuddyLayer.floating.rawValue,
            Key.hasPosition: false,
            Key.sleepAfterMinutes: 3.0
        ])
    }

    private func set<T>(_ value: T, _ key: String) {
        defaults.set(value, forKey: key)
        onChange?()
    }

    var watchCursor: Bool {
        get { defaults.bool(forKey: Key.watchCursor) }
        set { set(newValue, Key.watchCursor) }
    }

    var followCursor: Bool {
        get { defaults.bool(forKey: Key.followCursor) }
        set { set(newValue, Key.followCursor) }
    }

    /// Whether he wanders off to loiter along the menu bar, the Dock and the
    /// screen edges of his own accord.
    var hangOut: Bool {
        get { defaults.bool(forKey: Key.hangOut) }
        set { set(newValue, Key.hangOut) }
    }

    var reactToClaude: Bool {
        get { defaults.bool(forKey: Key.reactToClaude) }
        set { set(newValue, Key.reactToClaude) }
    }

    var clickThrough: Bool {
        get { defaults.bool(forKey: Key.clickThrough) }
        set { set(newValue, Key.clickThrough) }
    }

    var visible: Bool {
        get { defaults.bool(forKey: Key.visible) }
        set { set(newValue, Key.visible) }
    }

    var size: BuddySize {
        get { BuddySize(rawValue: defaults.string(forKey: Key.size) ?? "") ?? .medium }
        set { set(newValue.rawValue, Key.size) }
    }

    var layer: BuddyLayer {
        get { BuddyLayer(rawValue: defaults.string(forKey: Key.layer) ?? "") ?? .floating }
        set { set(newValue.rawValue, Key.layer) }
    }

    /// Minutes of pointer stillness before he dozes off.
    var sleepAfterMinutes: Double {
        get { max(0.5, defaults.double(forKey: Key.sleepAfterMinutes)) }
        set { set(newValue, Key.sleepAfterMinutes) }
    }

    /// Saved bottom-left origin of the panel, in screen coordinates.
    var position: CGPoint? {
        get {
            guard defaults.bool(forKey: Key.hasPosition) else { return nil }
            return CGPoint(x: defaults.double(forKey: Key.positionX),
                           y: defaults.double(forKey: Key.positionY))
        }
        set {
            if let point = newValue {
                defaults.set(point.x, forKey: Key.positionX)
                defaults.set(point.y, forKey: Key.positionY)
                defaults.set(true, forKey: Key.hasPosition)
            } else {
                defaults.set(false, forKey: Key.hasPosition)
            }
            // Deliberately no onChange: position is written on every drag frame
            // and re-applying window state there would fight the drag.
        }
    }
}
