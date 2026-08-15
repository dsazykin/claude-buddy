import AppKit
import SwiftUI

/// Owns the panel, the sensors, and the logic that turns them into a mood,
/// a place to stand, and the odd bit of idle business.
final class BuddyController {
    /// Supplies the menu shown when the character is right-clicked.
    var contextMenu: (() -> NSMenu?)?

    /// An edge of the screen he likes to loiter against.
    private enum Perch: CaseIterable {
        /// Under the menu bar.
        case top
        /// Above the Dock.
        case bottom
        case left
        case right
    }

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

    private var perch: Perch = .bottom
    /// Where he is walking to, as the character box's bottom-left in screen
    /// coordinates — *not* a panel origin. Flipping the speech bubble from one
    /// side of him to the other moves the panel out from under him, which would
    /// otherwise shift the target mid-walk.
    private var walkTarget: CGPoint?
    private var walkTimer: Timer?
    private var wanderTimer: Timer?
    private var idleTimer: Timer?

    /// Pointer distance at which he notices you, with hysteresis so the mood
    /// does not chatter when you hover at exactly that radius.
    private let curiousRadius: CGFloat = 130
    private let stopFollowingRadius: CGFloat = 150
    private let startFollowingRadius: CGFloat = 220

    /// How fast he ambles, in points per second.
    private let walkSpeed: CGFloat = 92

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    // MARK: - Lifecycle

    func start() {
        let scale = preferences.size.scale
        state.scale = scale

        let size = Layout.panelSize(for: scale)
        let panel = BuddyPanel(size: size)
        let container = BuddyContainerView(frame: NSRect(origin: .zero, size: size))
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

        // Saved as his own position, so it does not depend on which side the
        // bubble happened to be on when he was last put away.
        let restored = preferences.position.map { panelOrigin(forCharacter: $0) } ?? defaultPosition()
        panel.setFrameOrigin(clamped(restored, size: size))
        updateBubbleSide()

        pointer.onUpdate = { [weak self] location in self?.pointerMoved(to: location) }
        activity.onChange = { [weak self] activity in self?.claudeActivityChanged(activity) }

        preferences.onChange = { [weak self] in self?.applyPreferences() }
        applyPreferences()

        pointer.start()
        state.startBlinking()
        scheduleIdleGesture()

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
        stopWalking()
        wanderTimer?.invalidate()
        idleTimer?.invalidate()
        savePosition(force: true)
    }

    // MARK: - Preferences

    private func applyPreferences() {
        guard let panel, let container else { return }

        let scale = preferences.size.scale
        let newSize = Layout.panelSize(for: scale)
        if panel.frame.size != newSize {
            // Keep his feet where they were: anchor bottom-centre of the character.
            let oldBox = characterBoxInPanel()
            let anchor = CGPoint(x: panel.frame.origin.x + oldBox.midX,
                                 y: panel.frame.origin.y + oldBox.minY)
            state.scale = scale
            let newBox = characterBoxInPanel()

            panel.setContentSize(newSize)
            container.frame = NSRect(origin: .zero, size: newSize)
            panel.setFrameOrigin(clamped(CGPoint(x: anchor.x - newBox.midX,
                                                 y: anchor.y - newBox.minY),
                                         size: newSize))
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

        if preferences.hangOut && preferences.visible {
            scheduleWander()
        } else {
            wanderTimer?.invalidate()
            wanderTimer = nil
            if walkTarget != nil { stopWalking() }
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
        guard isFollowing else {
            if state.isWalking { stopWalking() }
            return
        }

        // Chasing the cursor wins over loitering.
        walkTarget = nil
        walkTimer?.invalidate()
        walkTimer = nil
        state.cancelGesture()

        // Close the gap to a comfortable resting distance, approaching from
        // whichever side he happens to be on rather than lunging at the cursor.
        let restDistance: CGFloat = 110
        let unit = CGPoint(x: (eye.x - location.x) / max(distance, 1),
                           y: (eye.y - location.y) / max(distance, 1))
        let target = CGPoint(x: location.x + unit.x * restDistance,
                             y: location.y + unit.y * restDistance)
        let step = CGPoint(x: (target.x - eye.x) * 0.10, y: (target.y - eye.y) * 0.10)
        let capped = CGPoint(x: max(-14, min(14, step.x)), y: max(-14, min(14, step.y)))

        state.isWalking = true
        if abs(capped.x) > 0.4 { state.facing = capped.x > 0 ? 1 : -1 }

        let origin = CGPoint(x: panel.frame.origin.x + capped.x, y: panel.frame.origin.y + capped.y)
        panel.setFrameOrigin(clamped(origin, size: panel.frame.size))
        updateBubbleSide()
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
            state.cancelGesture()
            stopWalking()
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
            state.perform(.hop)
        } else if !activity.isRunning, let since = claudeRunningSince {
            claudeRunningSince = nil
            // Skip the send-off for a session that barely started.
            if Date().timeIntervalSince(since) > 15 {
                state.say(quips.random(.done))
                state.perform(.hop)
            }
        }

        updateMood(pointerDistance: currentPointerDistance())
    }

    private func currentPointerDistance() -> CGFloat {
        guard let panel else { return .greatestFiniteMagnitude }
        let eye = eyePointOnScreen(panel: panel)
        return hypot(pointer.location.x - eye.x, pointer.location.y - eye.y)
    }

    // MARK: - Hanging out

    /// Wanders to a new perch every so often, so he drifts around the edges of
    /// the screen over the course of a session instead of sitting in one spot.
    private func scheduleWander() {
        wanderTimer?.invalidate()
        guard preferences.hangOut else { return }
        let delay = Double.random(in: 25...70)
        wanderTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.wanderNow()
            self?.scheduleWander()
        }
    }

    private func wanderNow() {
        guard preferences.hangOut, preferences.visible, !preferences.followCursor else { return }
        guard !state.isDragging, state.mood != .sleeping, !state.isWalking else { return }
        walk(to: nextPerch())
    }

    /// A spot to hang out: along the menu bar, above the Dock, or tucked against
    /// one of the side borders.
    private func nextPerch() -> CGPoint {
        guard let panel, let screen = currentScreen(for: panel.frame.origin) else {
            return panel?.frame.origin ?? .zero
        }
        let bounds = preferences.layer == .desktop ? screen.frame : screen.visibleFrame
        let box = characterBoxInPanel()

        // Mostly stroll along the edge he is already on; occasionally move house.
        if Double.random(in: 0...1) < 0.32 {
            perch = Perch.allCases.filter { $0 != perch }.randomElement() ?? perch
        }

        let inset: CGFloat = 14

        switch perch {
        case .top, .bottom:
            let span = max(0, bounds.width - box.width - inset * 2)
            return CGPoint(x: bounds.minX + inset + CGFloat.random(in: 0...span),
                           y: perch == .top ? bounds.maxY - box.height : bounds.minY)
        case .left, .right:
            let span = max(0, bounds.height - box.height - inset * 2)
            // Tucked a little past the border, as though leaning on it.
            return CGPoint(x: perch == .left ? bounds.minX - box.width * 0.18
                                             : bounds.maxX - box.width * 0.82,
                           y: bounds.minY + inset + CGFloat.random(in: 0...span))
        }
    }

    /// `target` is a character-box origin on screen.
    private func walk(to target: CGPoint) {
        guard let panel else { return }
        let reachable = clamped(panelOrigin(forCharacter: target), size: panel.frame.size)
        walkTarget = characterOrigin(forPanel: reachable)
        state.cancelGesture()
        state.isWalking = true

        walkTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.stepWalk()
        }
        RunLoop.main.add(timer, forMode: .common)
        walkTimer = timer
    }

    private func stepWalk() {
        guard let panel, let target = walkTarget else {
            stopWalking()
            return
        }

        let current = characterOrigin(forPanel: panel.frame.origin)
        let dx = target.x - current.x
        let dy = target.y - current.y
        let remaining = hypot(dx, dy)

        guard remaining > 1.5 else {
            panel.setFrameOrigin(clamped(panelOrigin(forCharacter: target), size: panel.frame.size))
            stopWalking()
            updateBubbleSide()
            savePosition(force: true)
            return
        }

        let stride = min(walkSpeed / 60, remaining)
        let next = CGPoint(x: current.x + dx / remaining * stride,
                           y: current.y + dy / remaining * stride)
        if abs(dx) > 1 { state.facing = dx > 0 ? 1 : -1 }
        panel.setFrameOrigin(clamped(panelOrigin(forCharacter: next), size: panel.frame.size))
        updateBubbleSide()
        savePosition(force: false)
    }

    private func stopWalking() {
        walkTimer?.invalidate()
        walkTimer = nil
        walkTarget = nil
        if state.isWalking { state.isWalking = false }
        state.facing = 0
    }

    // MARK: - Idle business

    /// Unprompted little animations, so standing still is not completely static.
    private func scheduleIdleGesture() {
        idleTimer?.invalidate()
        let delay = Double.random(in: 7...18)
        idleTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.performIdleGesture()
            self?.scheduleIdleGesture()
        }
    }

    private func performIdleGesture() {
        guard preferences.visible, !preferences.clickThrough else { return }
        guard !state.isDragging, !state.isWalking, state.mood != .sleeping else { return }
        guard state.gesture == nil else { return }

        var choices: [BuddyState.Gesture] = [.hop, .stretch, .wiggle, .glance, .blinkTwice]
        // Yawning only makes sense when nothing is going on.
        if state.mood == .idle { choices.append(contentsOf: [.yawn, .glance]) }
        // Glancing around does not read while his eyes are already tracking you.
        if state.mood == .curious { choices.removeAll { $0 == .glance } }

        guard let gesture = choices.randomElement() else { return }
        state.perform(gesture)
    }

    // MARK: - Interaction

    private func beginDrag() {
        guard let panel else { return }
        stopWalking()
        state.cancelGesture()
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
        updateBubbleSide()
        savePosition(force: true)

        // A click is a drag that never went anywhere.
        if dragDistance < 4 {
            speakRandomly()
        } else {
            // Dropped somewhere new: settle in before wandering off again.
            scheduleWander()
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
        if state.mood != .sleeping, state.gesture == nil {
            state.perform([.hop, .wiggle].randomElement() ?? .hop)
        }
    }

    private func showContextMenu(with event: NSEvent) {
        guard let menu = contextMenu?(), let container else { return }
        menu.popUp(positioning: nil, at: container.convert(event.locationInWindow, from: nil), in: container)
    }

    // MARK: - Geometry

    private func currentInteractiveRegions() -> [CGRect] {
        var regions = [characterBoxInPanel()]
        if state.isSpeaking {
            regions.append(Layout.bubbleHitRect(for: state.scale, bubbleBelow: state.bubbleBelow))
        }
        return regions
    }

    /// The character's box within the panel, in AppKit coordinates.
    private func characterBoxInPanel() -> CGRect {
        Layout.characterHitRect(for: state.scale, bubbleBelow: state.bubbleBelow)
    }

    /// Converting between where the panel is and where he appears to be. The
    /// two differ by the bubble strip, which swaps sides as he moves.
    private func characterOrigin(forPanel origin: CGPoint) -> CGPoint {
        let box = characterBoxInPanel()
        return CGPoint(x: origin.x + box.minX, y: origin.y + box.minY)
    }

    private func panelOrigin(forCharacter origin: CGPoint) -> CGPoint {
        let box = characterBoxInPanel()
        return CGPoint(x: origin.x - box.minX, y: origin.y - box.minY)
    }

    /// Where his eyes are, in screen coordinates.
    private func eyePointOnScreen(panel: NSPanel) -> CGPoint {
        let eye = Layout.eyePoint(for: state.scale, bubbleBelow: state.bubbleBelow)
        return CGPoint(x: panel.frame.origin.x + eye.x, y: panel.frame.origin.y + eye.y)
    }

    /// Puts the bubble on whichever side of him has room for it. The panel origin
    /// is compensated so that flipping does not move him on screen.
    private func updateBubbleSide() {
        guard let panel, let screen = currentScreen(for: panel.frame.origin) else { return }
        let characterTop = panel.frame.origin.y + characterBoxInPanel().maxY
        let roomAbove = screen.visibleFrame.maxY - characterTop
        setBubbleBelow(roomAbove < Layout.bubbleAreaHeight + 8)
    }

    private func setBubbleBelow(_ below: Bool) {
        guard below != state.bubbleBelow, let panel else { return }
        state.bubbleBelow = below
        // The character sits `bubbleAreaHeight` higher inside the panel when the
        // bubble is below him, so drop the panel by the same amount.
        let shift = below ? -Layout.bubbleAreaHeight : Layout.bubbleAreaHeight
        panel.setFrameOrigin(CGPoint(x: panel.frame.origin.x, y: panel.frame.origin.y + shift))
    }

    private func currentScreen(for origin: CGPoint) -> NSScreen? {
        let box = characterBoxInPanel()
        let centre = CGPoint(x: origin.x + box.midX, y: origin.y + box.midY)
        return NSScreen.screens.first { $0.frame.contains(centre) } ?? NSScreen.main
    }

    private func defaultPosition() -> CGPoint {
        guard let screen = NSScreen.main else { return .zero }
        let bounds = preferences.layer == .desktop ? screen.frame : screen.visibleFrame
        let box = characterBoxInPanel()
        // Loitering in the bottom-right, just above the Dock.
        return panelOrigin(forCharacter: CGPoint(x: bounds.maxX - box.width - 18, y: bounds.minY))
    }

    /// Keeps the character — not the transparent panel around him — on screen,
    /// while still letting him tuck a little past an edge.
    private func clamped(_ origin: CGPoint, size: CGSize) -> CGPoint {
        guard let screen = currentScreen(for: origin) else { return origin }

        // On the desktop layer he may sit under the menu bar and Dock.
        let bounds = preferences.layer == .desktop ? screen.frame : screen.visibleFrame
        let box = characterBoxInPanel()
        let slackX = box.width * 0.34
        let slackY = box.height * 0.34

        let minX = bounds.minX - box.minX - slackX
        let maxX = bounds.maxX - box.maxX + slackX
        let minY = bounds.minY - box.minY - slackY
        let maxY = bounds.maxY - box.maxY + slackY

        return CGPoint(x: min(max(origin.x, minX), maxX),
                       y: min(max(origin.y, minY), maxY))
    }

    func reclampPosition() {
        guard let panel else { return }
        panel.setFrameOrigin(clamped(panel.frame.origin, size: panel.frame.size))
        updateBubbleSide()
        savePosition(force: true)
    }

    func resetPosition() {
        guard let panel else { return }
        stopWalking()
        panel.setFrameOrigin(clamped(defaultPosition(), size: panel.frame.size))
        updateBubbleSide()
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
