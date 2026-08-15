import SwiftUI

struct SpeechBubbleView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12.5, weight: .medium, design: .rounded))
            .foregroundColor(Palette.ink)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .padding(.bottom, 9) // room for the tail
            .frame(maxWidth: Layout.bubbleMaxWidth)
            .background(
                BubbleShape()
                    .fill(Palette.cream)
                    .overlay(
                        BubbleShape()
                            .stroke(Palette.shadow.opacity(0.10), lineWidth: 1)
                    )
                    .shadow(color: Palette.shadow.opacity(0.22), radius: 7, x: 0, y: 3)
            )
    }
}
