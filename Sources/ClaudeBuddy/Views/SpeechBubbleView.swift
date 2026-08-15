import SwiftUI

struct SpeechBubbleView: View {
    let text: String
    /// True when the bubble hangs below him and its tail points up.
    var tailOnTop = false

    var body: some View {
        Text(text)
            .font(.system(size: 12.5, weight: .medium, design: .rounded))
            .foregroundColor(Palette.ink)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            // Room for the tail, on whichever side it is on.
            .padding(tailOnTop ? .top : .bottom, 9)
            .frame(maxWidth: Layout.bubbleMaxWidth)
            .background(
                BubbleShape(tailOnTop: tailOnTop)
                    .fill(Palette.cream)
                    .overlay(
                        BubbleShape(tailOnTop: tailOnTop)
                            .stroke(Palette.shadow.opacity(0.10), lineWidth: 1)
                    )
                    .shadow(color: Palette.shadow.opacity(0.22), radius: 7, x: 0, y: 3)
            )
    }
}
