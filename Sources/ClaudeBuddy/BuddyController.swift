import AppKit
import SwiftUI

/// Owns the panel, the sensors, and the logic that turns them into a mood.
final class BuddyController {
    /// Supplies the menu shown when the character is right-clicked.
    var contextMenu: (() -> NSMenu?)?

    private let preferences: Preferences
    private let state = BuddyState()
    private let pointer = PointerTracker()
    private let activity = ClaudeActivityMonitor()
    private let quips = QuipLibrary.shared

    private var panel: BuddyPanel?
    private var container: BuddyContainerView?

    private var dragAnchor: (origin: CGPoint, mouse: CGPoint)?
    private var dragDistance: CGFloat = 0
    private var lastPositionSave = Date.distantPast
    private var claudeRunningSince: Date?
    private var wasSleeping = false
    private var greeted = false

    /// Pointer distance at which he notices you, with hysteresis so the mood
    /// does not chatter when you hover at exactly that radius.
    private let curiousRadius: CGFloat = 170
    private let stopFollowingRadius: CGFloat = 190
    private let startFollowingRadius: CGFloat = 260

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    // MARK: - Lifecycle

    func start() {
        let scale = preferences.size.scale
        state.scale = scale

        let panel = BuddyPanel(size: Layout.panelSize(for: scale))
        let container = BuddyContainerView(frame: NSRect(origin: .zero, size: Layout.panelSize(for: scale)))
        container.interactiveRegions = { [weak self] in self?.currentInteractiveRegions() ?? [] }
        container.onMouseDown = { [weak self] in self?.beginDrag() }
        container.onMouseDragged = { [weak self] in self?.updateDrag() }
        container.onMouseUp = { [weak self] in self?.endDrag() }
        container.onRightMouseDown = { [weak self] event in self?.showContextMenu(with: event) }

        let hosting = NSHostingView(rootView: BuddyView(state: state))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        panel.contentView = container
        self.panel = panel
        self.container = container

        panel.setFrameOrigin(clamped(preferences.position ?? defaultPosition(for: panel.frame.size),
                                     size: panel.frame.size))

        pointer.onUpdate = { [weak self] location in self?.pointerMoved(to: location) }
        activity.onChange = { [weak self] activity in self?.claudeActivityChanged(activity) }

        preferences.onChange = { [weak self] in self?.applyPreferences() }
        applyPreferences()

        pointer.start()
        state.startBlinking()

        Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] _ in
            guard let self, !self.greeted else { return }
            self.greeted = true
            self.state.say(self.quips.random(.greeting))
        }
    }

    func stop() {
        pointer.stop()
        activity.stop()
        state.stopBlinking()
        savePosition(force: true)
    }

    // MARK: - Preferences

    private func applyPreferences() {
        guard let panel, let container else { return }

        let scale = preferences.size.scale
        let newSize = Layout.panelSize(for: scale)
        if panel.frame.size != newSize {
            // Keep his feet where they were: anchor bottom-centre.
            let old = panel.frame
            let origin = CGPoint(x: old.origin.x + (old.width - newSize.width) / 2, y: old.origin.y)
            panel.setContentSize(newSize)
            container.frame = NSRect(origin: .zero, size: newSize)
            panel.setFrameOrigin(clamped(origin, size: newSize))
            state.scale = scale
            savePosition(force: true)
        }

        panel.level = preferences.layer.windowLevel
        panel.ignoresMouseEvents = preferences.clickThrough

        if preferences.visible {
            panel.orderFront(nil)
        } else {
            panel.orderOut(nil)
        }

        if preferences.reactToClaude {
            activity.start()
        } else {
            activity.stop()
        }

        if !preferences.watchCursor {
            state.look = .zero
            state.tilt = 0
        }
    }

    // MARK: - Pointer

    private func pointerMoved(to location: CGPoint) {
        guard let panel, preferences.visible else { return }

        let eye = eyePointOnScreen(panel: panel)
        let dx = location.x - eye.x
        let dy = location.y - eye.y
        let distance = hypot(dx, dy)

        if preferences.watchCursor && !preferences.clickThrough {
            // Soft saturation, so nearby movement is expressive and far-away
            // movement does not peg the eyes to the edge.
            let falloff: CGFloat = 220
            let ux = dx / sqrt(dx * dx + falloff * falloff)
            let uy = dy / sqrt(dy * dy + falloff * falloff)
            state.look = CGSize(width: ux, height: -uy)
            state.tilt = max(-6, min(6, ux * 6))
        }

        if preferences.followCursor && !state.isDragging && !preferences.clickThrough {
            follow(pointer: location, from: eye, distance: distance)
        }

        updateMood(pointerDistance: distance)
    }

    private func follow(pointer location: CGPoint, from eye: CGPoint, distance: CGFloat) {
        guard let panel else { return }
        guard distance > startFollowingRadius || isFollowing else { return }
        isFollowing = distance > stopFollowingRadius
        guard isFollowing else { return }

        // Close the gap to a comfortable resting distance, approaching from
        // whichever side he happens to be on rather than lunging at the cursor.
        let restDistance: CGFloat = 150
        let unit = CGPoint(x: (eye.x - location.x) / max(distance, 1),
                           y: (eye.y - location.y) / max(distance, 1))
        let target = CGPoint(x: location.x + unit.x * restDistance,
                             y: location.y + unit.y * restDistance)
        let step = CGPoint(x: (target.x - eye.x) * 0.10, y: (target.y - eye.y) * 0.10)
        let capped = CGPoint(x: max(-14, min(14, step.x)), y: max(-14, min(14, step.y)))
        let origin = CGPoint(x: panel.frame.origin.x + capped.x, y: panel.frame.origin.y + capped.y)
        panel.setFrameOrigin(clamped(origin, size: panel.frame.size))
        savePosition(force: false)
    }

    private var isFollowing = false

    private func updateMood(pointerDistance: CGFloat) {
        let sleepAfter = preferences.sleepAfterMinutes * 60
        let next: Mood

        if preferences.reactToClaude && activity.activity.isBusy {
            next = .thinking
        } else if preferences.reactToClaude && activity.activity.isRunning {
            next = .working
        } else if pointer.stillnessDuration > sleepAfter {
            next = .sleeping
        } else if preferences.watchCursor && pointerDistance < curiousRadius {
            next = .curious
        } else {
            next = .idle
        }

        guard next != state.mood else { return }

        if wasSleeping && next != .sleeping {
            wasSleeping = false
            if Double.random(in: 0...1) < 0.4 {
                state.say(quips.random(.sleepy))
            }
        }
        if next == .sleeping {
            wasSleeping = true
            state.hush()
        }

        withAnimation(.easeInOut(duration: 0.28)) {
            state.mood = next
        }
    }

    // MARK: - Claude Code activity

    private func claudeActivityChanged(_ activity: ClaudeActivityMonitor.Activity) {
        guard preferences.reactToClaude else { return }

        if activity.isRunning, claudeRunningSince == nil {
            claudeRunningSince = Date()
            state.say(quips.random(.working))
        } else if !activity.isRunning, let since = claudeRunningSince {
            claudeRunningSince = nil
            // Skip the send-off for a session that barely started.
            if Date().timeIntervalSince(since) > 15 {
                state.say(quips.random(.done))
            }
        }

        updateMood(pointerDistance: currentPointerDistance())
    }

    private func currentPointerDistance() -> CGFloat {
        guard let panel else { return .greatestFiniteMagnitude }
        let eye = eyePointOnScreen(panel: panel)
        return hypot(pointer.location.x - eye.x, pointer.location.y - eye.y)
    }

    // MARK: - Interaction

    private func beginDrag() {
        guard let panel else { return }
        dragAnchor = (panel.frame.origin, NSEvent.mouseLocation)
        dragDistance = 0
        state.isDragging = true
        isFollowing = false
    }

    private func updateDrag() {
        guard let panel, let anchor = dragAnchor else { return }
        // Track against the pointer's absolute position rather than a gesture
        // translation: the window moves out from under the cursor, which makes
        // relative deltas drift.
        let mouse = NSEvent.mouseLocation
        let dx = mouse.x - anchor.mouse.x
        let dy = mouse.y - anchor.mouse.y
        dragDistance = max(dragDistance, hypot(dx, dy))
        let origin = CGPoint(x: anchor.origin.x + dx, y: anchor.origin.y + dy)
        panel.setFrameOrigin(clamped(origin, size: panel.frame.size))
    }

    private func endDrag() {
        state.isDragging = false
        dragAnchor = nil
        savePosition(force: true)

        // A click is a drag that never went anywhere.
        if dragDistance < 4 {
            speakRandomly()
        }
        dragDistance = 0
    }

    func speakRandomly() {
        let category: QuipCategory
        switch state.mood {
        case .working, .thinking: category = .working
        case .sleeping: category = .sleepy
        default: category = Bool.random() ? .idle : .greeting
        }
        state.say(quips.random(category))
    }

    private func showContextMenu(with event: NSEvent) {
        guard let menu = contextMenu?(), let container else { return }
        menu.popUp(positioning: nil, at: container.convert(event.locationInWindow, from: nil), in: container)
    }

    // MARK: - Geometry

    private func currentInteractiveRegions() -> [CGRect] {
        let scale = state.scale
        var regions = [Layout.scaled(Layout.characterHitRect, scale)]
        if state.isSpeaking {
            regions.append(Layout.scaled(Layout.bubbleHitRect, scale))
        }
        return regions
    }

    /// Where his eyes are, in screen coordinates.
    private func eyePointOnScreen(panel: NSPanel) -> CGPoint {
        let scale = state.scale
        return CGPoint(x: panel.frame.origin.x + 120 * scale,
                       y: panel.frame.origin.y + 74 * scale)
    }

    private func defaultPosition(for size: CGSize) -> CGPoint {
        guard let screen = NSScreen.main else { return .zero }
        let frame = screen.visibleFrame
        return CGPoint(x: frame.maxX - size.width - 24, y: frame.minY + 24)
    }

    /// Keeps most of him on some screen without forcing him fully inside, so he
    /// can still tuck into a corner.
    private func clamped(_ origin: CGPoint, size: CGSize) -> CGPoint {
        let centre = CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
        let screen = NSScreen.screens.first { $0.frame.contains(centre) }
            ?? NSScreen.main
        guard let screen else { return origin }

        // On the desktop layer he may sit under the menu bar and Dock.
        let bounds = preferences.layer == .desktop ? screen.frame : screen.visibleFrame
        let minX = bounds.minX - size.width * 0.3
        let maxX = bounds.maxX - size.width * 0.7
        let minY = bounds.minY - size.height * 0.15
        let maxY = bounds.maxY - size.height * 0.9

        return CGPoint(x: min(max(origin.x, minX), maxX),
                       y: min(max(origin.y, minY), maxY))
    }

    func reclampPosition() {
        guard let panel else { return }
        panel.setFrameOrigin(clamped(panel.frame.origin, size: panel.frame.size))
        savePosition(force: true)
    }

    func resetPosition() {
        guard let panel else { return }
        let origin = defaultPosition(for: panel.frame.size)
        panel.setFrameOrigin(clamped(origin, size: panel.frame.size))
        savePosition(force: true)
        state.say("back to my corner")
    }

    private func savePosition(force: Bool) {
        guard let panel else { return }
        let now = Date()
        guard force || now.timeIntervalSince(lastPositionSave) > 1 else { return }
        lastPositionSave = now
        preferences.position = panel.frame.origin
    }
}
