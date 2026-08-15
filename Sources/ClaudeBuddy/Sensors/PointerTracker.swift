import AppKit

/// Polls the global pointer location.
///
/// Polling `NSEvent.mouseLocation` is deliberate: a global event monitor for
/// mouse-moved events would require Accessibility permission, and a desktop pet
/// should not have to ask for that.
final class PointerTracker {
    private(set) var location: CGPoint = NSEvent.mouseLocation
    private(set) var lastMovement = Date()

    /// Seconds since the pointer last moved.
    var stillnessDuration: TimeInterval { Date().timeIntervalSince(lastMovement) }

    var onUpdate: ((CGPoint) -> Void)?

    private var timer: Timer?
    private let interval: TimeInterval

    init(interval: TimeInterval = 1.0 / 30.0) {
        self.interval = interval
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // .common so polling survives menu tracking and window drags.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let current = NSEvent.mouseLocation
        if hypot(current.x - location.x, current.y - location.y) > 0.8 {
            lastMovement = Date()
        }
        location = current
        onUpdate?(current)
    }

    deinit { stop() }
}
