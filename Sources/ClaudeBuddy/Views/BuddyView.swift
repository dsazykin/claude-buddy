import SwiftUI

/// Root of the panel's content: a speech bubble strip above, the character
/// below. Laid out at base size and scaled about its centre, which keeps the
/// AppKit hit-test rectangles a simple multiplication away.
struct BuddyView: View {
    @ObservedObject var state: BuddyState

    var body: some View {
        TimelineView(.animation(minimumInterval: state.mood.frameInterval)) { context in
            // Wrapped to an hour so the animation maths stays in a small range.
            let time = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)

            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    Color.clear
                    if let speech = state.speech {
                        SpeechBubbleView(text: speech.text)
                            .id(speech.id)
                            .transition(
                                .scale(scale: 0.8, anchor: .bottom).combined(with: .opacity)
                            )
                    }
                }
                .frame(width: Layout.basePanelSize.width, height: Layout.bubbleAreaHeight)

                CharacterView(time: time, state: state)
            }
            .frame(width: Layout.basePanelSize.width, height: Layout.basePanelSize.height)
        }
        .scaleEffect(state.scale)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
