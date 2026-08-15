import SwiftUI

/// Everything the views draw from. Owned by `BuddyController`, observed by
/// `BuddyView`.
final class BuddyState: ObservableObject {
    struct Speech: Equatable, Identifiable {
        let id: Int
        let text: String
    }

    /// Current disposition, decided by the controller.
    @Published var mood: Mood = .idle
    /// Where he is looking, as a unit vector in view space (x right, y down).
    @Published var look: CGSize = .zero
    /// Body lean toward the pointer, in degrees.
    @Published var tilt: CGFloat = 0
    @Published var isBlinking = false
    @Published var isDragging = false
    @Published var speech: Speech?
    @Published var scale: CGFloat = 1

    /// True while he is actually travelling somewhere under his own steam.
    @Published var isWalking = false
    /// Direction of travel: -1 left, +1 right, 0 standing still.
    @Published var facing: CGFloat = 0
    /// Bubble hangs below him when he is perched too high for it to fit above.
    @Published var bubbleBelow = false

    /// A one-off bit of business he is doing right now, and when it started.
    @Published private(set) var gesture: Gesture?
    private(set) var gestureStart = Date.distantPast

    private var speechCounter = 0
    private var speechDismissTimer: Timer?
    private var blinkTimer: Timer?
    private var gestureTimer: Timer?

    // MARK: - Speech

    func say(_ text: String, for duration: TimeInterval = 4.2) {
        speechCounter += 1
        let speech = Speech(id: speechCounter, text: text)
        withAnimation(.spring(response: 0.34, dampingFraction: 0.62)) {
            self.speech = speech
        }

        speechDismissTimer?.invalidate()
        speechDismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            guard let self, self.speech?.id == speech.id else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                self.speech = nil
            }
        }
    }

    func hush() {
        speechDismissTimer?.invalidate()
        speechDismissTimer = nil
        withAnimation(.easeOut(duration: 0.18)) { speech = nil }
    }

    var isSpeaking: Bool { speech != nil }

    // MARK: - Idle gestures

    /// Little unprompted bits of business, so standing around still has some
    /// life in it. Each one is a pure function of elapsed time in the views.
    enum Gesture: CaseIterable {
        /// A small jump on the spot.
        case hop
        /// Draws himself up tall and settles back down.
        case stretch
        /// A quick side-to-side shimmy.
        case wiggle
        /// Looks off to one side, then the other.
        case glance
        /// Two quick blinks.
        case blinkTwice
        /// Eyes shut, mouth wide open.
        case yawn

        var duration: TimeInterval {
            switch self {
            case .hop: return 0.55
            case .stretch: return 1.5
            case .wiggle: return 0.9
            case .glance: return 2.2
            case .blinkTwice: return 1.0
            case .yawn: return 1.7
            }
        }
    }

    func perform(_ gesture: Gesture) {
        gestureTimer?.invalidate()
        gestureStart = Date()
        self.gesture = gesture
        gestureTimer = Timer.scheduledTimer(withTimeInterval: gesture.duration, repeats: false) { [weak self] _ in
            self?.gesture = nil
        }
    }

    func cancelGesture() {
        gestureTimer?.invalidate()
        gestureTimer = nil
        gesture = nil
    }

    /// How far through the current gesture we are, 0...1.
    func gestureProgress(at date: Date) -> CGFloat {
        guard let gesture else { return 0 }
        let elapsed = date.timeIntervalSince(gestureStart)
        return CGFloat(min(1, max(0, elapsed / gesture.duration)))
    }

    // MARK: - Blinking

    func startBlinking() {
        scheduleBlink()
    }

    func stopBlinking() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        isBlinking = false
    }

    private func scheduleBlink() {
        blinkTimer?.invalidate()
        let delay = Double.random(in: 2.4...6.8)
        blinkTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            // Eyes are already shut while asleep; skip the flicker.
            guard self.mood != .sleeping else {
                self.scheduleBlink()
                return
            }
            self.isBlinking = true
            Timer.scheduledTimer(withTimeInterval: 0.12, repeats: false) { [weak self] _ in
                self?.isBlinking = false
                self?.scheduleBlink()
            }
        }
    }

    deinit {
        speechDismissTimer?.invalidate()
        blinkTimer?.invalidate()
        gestureTimer?.invalidate()
    }
}
