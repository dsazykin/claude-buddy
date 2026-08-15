import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

enum Palette {
    /// Claude coral. The reference artwork is a brighter tomato (0xF05B45),
    /// which is loud at the size he is actually drawn, so he is toned down to
    /// the softer brand colour. He is deliberately not shaded: the original is
    /// one flat colour, and a gradient reads as a different character.
    static let body = Color(hex: 0xD97757)
    static let ink = Color(hex: 0x140C0A)
    static let cream = Color(hex: 0xFBF3EA)
    static let blush = Color(hex: 0xE0654A)
    static let sparkle = Color(hex: 0xFFD9B2)
    static let shadow = Color(hex: 0x2A1A12)
}

/// Speech bubble with a tail pointing toward his head — down when the bubble is
/// above him, up when he is perched high enough that it has to hang below.
struct BubbleShape: Shape {
    var cornerRadius: CGFloat = 12
    var tailWidth: CGFloat = 14
    var tailHeight: CGFloat = 9
    var tailOnTop = false

    func path(in rect: CGRect) -> Path {
        let body = CGRect(x: rect.minX,
                          y: tailOnTop ? rect.minY + tailHeight : rect.minY,
                          width: rect.width,
                          height: max(0, rect.height - tailHeight))
        var path = Path(roundedRect: body, cornerRadius: cornerRadius, style: .continuous)

        let tailCentre = body.minX + body.width * 0.42
        if tailOnTop {
            path.move(to: CGPoint(x: tailCentre + tailWidth / 2, y: body.minY + 1))
            path.addLine(to: CGPoint(x: tailCentre - tailWidth / 2, y: body.minY + 1))
            path.addQuadCurve(to: CGPoint(x: tailCentre + tailWidth / 2 - 2, y: rect.minY),
                              control: CGPoint(x: tailCentre - tailWidth / 4, y: body.minY - tailHeight * 0.6))
        } else {
            path.move(to: CGPoint(x: tailCentre - tailWidth / 2, y: body.maxY - 1))
            path.addLine(to: CGPoint(x: tailCentre + tailWidth / 2, y: body.maxY - 1))
            path.addQuadCurve(to: CGPoint(x: tailCentre - tailWidth / 2 + 2, y: rect.maxY),
                              control: CGPoint(x: tailCentre + tailWidth / 4, y: body.maxY + tailHeight * 0.6))
        }
        path.closeSubpath()
        return path
    }
}
