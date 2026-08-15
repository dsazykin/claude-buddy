import AppKit

/// Borderless, transparent, always-available panel that hosts the character.
final class BuddyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(size: NSSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        // Only take key focus if something inside actually needs it, so clicking
        // the buddy never pulls focus away from what you were typing in.
        becomesKeyOnlyIfNeeded = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    }
}

/// Content view that masks hit testing to the character's silhouette, so the
/// transparent remainder of the panel does not swallow desktop clicks.
final class BuddyContainerView: NSView {
    /// Evaluated live on each hit test, in this view's coordinates.
    var interactiveRegions: () -> [CGRect] = { [] }

    var onMouseDown: (() -> Void)?
    var onMouseDragged: (() -> Void)?
    var onMouseUp: (() -> Void)?
    var onRightMouseDown: ((NSEvent) -> Void)?

    override func hitTest(_ point: NSPoint) -> NSView? {
        // AppKit hands us a point in the superview's coordinate space; as a
        // window's content view there is no superview and it is already local.
        let local = superview.map { convert(point, from: $0) } ?? point
        guard interactiveRegions().contains(where: { $0.contains(local) }) else { return nil }
        // Return self rather than deferring to the SwiftUI hosting subview: the
        // character is presentation only and all input is handled here.
        return self
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) { onMouseDown?() }
    override func mouseDragged(with event: NSEvent) { onMouseDragged?() }
    override func mouseUp(with event: NSEvent) { onMouseUp?() }
    override func rightMouseDown(with event: NSEvent) { onRightMouseDown?(event) }
}
