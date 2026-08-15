import SwiftUI

/// Root of the panel's content: the character, with a speech bubble strip above
/// him — or below, when he is perched too high for a bubble to fit overhead.
///
/// Only the character is scaled. The bubble keeps its natural size so a small
/// buddy still has readable speech.
struct BuddyView: View {
    @ObservedObject var state: BuddyState

    var body: some View {
        TimelineView(.animation(minimumInterval: state.mood.frameInterval)) { context in
            // Wrapped to an hour so the animation maths stays in a small range.
            let time = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)

            VStack(spacing: 0) {
                if state.bubbleBelow {
                    character(time: time, now: context.date)
                    bubbleStrip(atTop: false)
                } else {
                    bubbleStrip(atTop: true)
                    character(time: time, now: context.date)
                }
            }
            .frame(width: Layout.panelWidth,
                   height: Layout.panelSize(for: state.scale).height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func character(time: Double, now: Date) -> some View {
        let box = Layout.characterBox(for: state.scale)
        return CharacterView(time: time, now: now, state: state)
            .scaleEffect(state.scale)
            .frame(width: box.width, height: box.height)
    }

    /// `atTop` means the strip is above him, so the bubble sits at the bottom of
    /// the strip with its tail pointing down at his head.
    private func bubbleStrip(atTop: Bool) -> some View {
        ZStack(alignment: atTop ? .bottom : .top) {
            Color.clear
            if let speech = state.speech {
                SpeechBubbleView(text: speech.text, tailOnTop: !atTop)
                    .id(speech.id)
                    .transition(
                        .scale(scale: 0.8, anchor: atTop ? .bottom : .top)
                            .combined(with: .opacity)
                    )
            }
        }
        .frame(width: Layout.panelWidth, height: Layout.bubbleAreaHeight)
    }
}
