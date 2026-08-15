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

    private var speechCounter = 0
    private var speechDismissTimer: Timer?
    private var blinkTimer: Timer?

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
    }
}
