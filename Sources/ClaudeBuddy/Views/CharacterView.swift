import SwiftUI

/// The buddy himself: a pixel character drawn in a 132 x 144 box.
///
/// The body is a sprite frame chosen from what he is doing; the eyes and mouth
/// are separate layers over it, so blinking, glancing and yawning do not each
/// need their own body frame. Everything is a pure function of `time`, `now` and
/// the state.
struct CharacterView: View {
    /// Wrapped animation clock, in seconds.
    let time: Double
    /// Unwrapped clock, for measuring progress through a gesture.
    let now: Date
    @ObservedObject var state: BuddyState

    /// The sprite's drawing box: 12 x 8 cells at 11 points each. The rest of
    /// the character box is headroom for sparkles and sleep "z"s.
    private static let spriteSize = CGSize(width: 132, height: 88)
    private static let cell: CGFloat = 11

    var body: some View {
        let mood: Mood = state.mood
        let gesture: BuddyState.Gesture? = state.gesture
        let progress: CGFloat = state.gestureProgress(at: now)
        /// One arch of a gesture: 0 at each end, 1 in the middle.
        let arch: CGFloat = gesture == nil ? 0 : sin(progress * .pi)

        let walking: Bool = state.isWalking
        let dragging: Bool = state.isDragging
        // Breathing, rounded to a whole point so he never sits between pixels.
        let breath: CGFloat = round(CGFloat(sin(time * 2 * .pi / mood.breathPeriod)) * 0.6)

        let hop: CGFloat = gesture == .hop ? -arch * Self.cell * 1.6 : 0
        let walkBounce: CGFloat = walking ? -abs(CGFloat(sin(time * mood.stepRate))) * 2 : 0
        let shuffle: CGFloat = gesture == .wiggle
            ? round(CGFloat(sin(progress * 6 * .pi))) * Self.cell * 0.5
            : 0
        let stretch: CGFloat = gesture == .stretch ? 1 + arch * 0.14 : 1

        return ZStack {
            ZStack {
                PixelShape(rows: bodyFrame(mood: mood, walking: walking,
                                           dragging: dragging, gesture: gesture, arch: arch))
                    .fill(Palette.body)

                eyes(mood: mood, dragging: dragging, gesture: gesture,
                     progress: progress, arch: arch)

                if gesture == .yawn, arch > 0.3 {
                    PixelShape(rows: Sprite.mouthOpen, ink: "o")
                        .fill(Palette.ink)
                }
            }
            .frame(width: Self.spriteSize.width, height: Self.spriteSize.height)
            .scaleEffect(y: stretch, anchor: .bottom)
            .offset(x: shuffle, y: hop + walkBounce + breath)

            sparkles(time: time, mood: mood)

            if mood == .sleeping {
                sleepZs(time: time)
            }
        }
        .frame(width: Layout.characterSize.width, height: Layout.characterSize.height)
    }

    // MARK: - Body

    private func bodyFrame(mood: Mood, walking: Bool, dragging: Bool,
                           gesture: BuddyState.Gesture?, arch: CGFloat) -> [String] {
        if dragging { return Sprite.dangling }
        if gesture == .hop && arch > 0.25 { return Sprite.airborne }
        if walking {
            // Two frames a stride, which is what makes it read as walking
            // rather than sliding.
            return sin(time * mood.stepRate) > 0 ? Sprite.walkA : Sprite.walkB
        }
        return Sprite.stand
    }

    // MARK: - Face

    private func eyes(mood: Mood, dragging: Bool, gesture: BuddyState.Gesture?,
                      progress: CGFloat, arch: CGFloat) -> some View {
        let shut = mood == .sleeping
            || (gesture == .yawn && arch > 0.35)
            || state.isBlinking
            || (gesture == .blinkTwice && blinkingTwice(progress))
        let frame = shut ? Sprite.eyesShut : Sprite.eyesOpen

        // The sprite is symmetrical, so he "turns" by looking where he is going
        // rather than by being mirrored. Glancing moves the eyes by whole cells;
        // watching the cursor nudges them by a fraction of one.
        let glance: CGFloat
        if gesture == .glance {
            glance = round(glanceCurve(progress)) * Self.cell
        } else if state.isWalking {
            glance = state.facing * Self.cell * 0.5
        } else {
            glance = state.look.width * Self.cell * 0.45
        }

        return PixelShape(rows: frame, ink: "o")
            .fill(Palette.ink)
            .offset(x: glance)
    }

    /// Two quick blinks: shut early in the gesture, and again just after halfway.
    private func blinkingTwice(_ progress: CGFloat) -> Bool {
        (progress > 0.10 && progress < 0.28) || (progress > 0.52 && progress < 0.70)
    }

    /// -1 → +1 → 0, with pauses at each end.
    private func glanceCurve(_ progress: CGFloat) -> CGFloat {
        switch progress {
        case ..<0.15: return -progress / 0.15
        case ..<0.35: return -1
        case ..<0.55: return -1 + (progress - 0.35) / 0.20 * 2
        case ..<0.80: return 1
        default: return 1 - (progress - 0.80) / 0.20
        }
    }

    // MARK: - Sparkles

    /// Three "z"s drifting up and to the right while he dozes.
    private func sleepZs(time: Double) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let phase = ((time * 0.4) + Double(index) * 0.34).truncatingRemainder(dividingBy: 1)
                let size = Self.cell * (1.1 + CGFloat(phase) * 0.5)

                // His own colour rather than ink: these float clear of him, over
                // whatever wallpaper happens to be behind.
                PixelShape(rows: Sprite.sleepZ, ink: "o", columns: 3, lines: 5)
                    .fill(Palette.body.opacity(0.85 * sin(phase * .pi)))
                    .frame(width: size * 0.6, height: size)
                    .offset(x: Self.cell * 3 + CGFloat(phase) * Self.cell * 1.6,
                            y: -Self.spriteSize.height / 2 - CGFloat(phase) * Self.cell * 1.8)
            }
        }
    }

    /// Twinkles either side of him while a Claude Code session is working.
    private func sparkles(time: Double, mood: Mood) -> some View {
        let blink = sin(time * 4)
        let size = Self.cell * 1.5

        // He fills the full width of his box, so these go above his head rather
        // than beside him, where they would be clipped.
        return ZStack {
            PixelShape(rows: Sprite.sparkle, ink: "o", columns: 3, lines: 3)
                .fill(Palette.sparkle)
                .frame(width: size, height: size)
                .opacity(blink > 0 ? 1 : 0.45)
                .offset(x: -Self.cell * 3.5, y: -Self.spriteSize.height / 2 - Self.cell)

            PixelShape(rows: Sprite.sparkle, ink: "o", columns: 3, lines: 3)
                .fill(Palette.sparkle)
                .frame(width: size, height: size)
                .opacity(blink > 0 ? 0.45 : 1)
                .offset(x: Self.cell * 3.5, y: -Self.spriteSize.height / 2 - Self.cell * 0.4)
        }
        .opacity(mood.isBusy ? 1 : 0)
    }
}
