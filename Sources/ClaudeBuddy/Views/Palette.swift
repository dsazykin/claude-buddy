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
    static let shellTop = Color(hex: 0xEC9B74)
    static let shellMid = Color(hex: 0xD97757)
    static let shellBottom = Color(hex: 0xB9573A)
    static let ink = Color(hex: 0x33201A)
    static let cream = Color(hex: 0xFBF3EA)
    static let blush = Color(hex: 0xE0654A)
    static let sparkle = Color(hex: 0xFFD9B2)
    static let shadow = Color(hex: 0x2A1A12)
}

/// Soft pebble body: rounder than a capsule, less regular than an ellipse.
struct BlobShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let x = rect.minX
        let y = rect.minY

        path.move(to: CGPoint(x: x + w * 0.5, y: y))
        path.addCurve(to: CGPoint(x: x + w, y: y + h * 0.54),
                      control1: CGPoint(x: x + w * 0.84, y: y),
                      control2: CGPoint(x: x + w, y: y + h * 0.20))
        path.addCurve(to: CGPoint(x: x + w * 0.5, y: y + h),
                      control1: CGPoint(x: x + w, y: y + h * 0.86),
                      control2: CGPoint(x: x + w * 0.80, y: y + h))
        path.addCurve(to: CGPoint(x: x, y: y + h * 0.54),
                      control1: CGPoint(x: x + w * 0.20, y: y + h),
                      control2: CGPoint(x: x, y: y + h * 0.86))
        path.addCurve(to: CGPoint(x: x + w * 0.5, y: y),
                      control1: CGPoint(x: x, y: y + h * 0.20),
                      control2: CGPoint(x: x + w * 0.16, y: y))
        path.closeSubpath()
        return path
    }
}

/// Four-pointed sparkle with concave sides.
struct SparkleShape: Shape {
    /// How far the waist pulls in toward the centre. Lower is spikier.
    var pinch: CGFloat = 0.30

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let waist = radius * pinch

        var path = Path()
        path.move(to: CGPoint(x: centre.x, y: centre.y - radius))
        path.addQuadCurve(to: CGPoint(x: centre.x + radius, y: centre.y),
                          control: CGPoint(x: centre.x + waist, y: centre.y - waist))
        path.addQuadCurve(to: CGPoint(x: centre.x, y: centre.y + radius),
                          control: CGPoint(x: centre.x + waist, y: centre.y + waist))
        path.addQuadCurve(to: CGPoint(x: centre.x - radius, y: centre.y),
                          control: CGPoint(x: centre.x - waist, y: centre.y + waist))
        path.addQuadCurve(to: CGPoint(x: centre.x, y: centre.y - radius),
                          control: CGPoint(x: centre.x - waist, y: centre.y - waist))
        path.closeSubpath()
        return path
    }
}

/// Mouth arc. Positive `curve` smiles, negative frowns, zero is a flat line.
struct MouthShape: Shape {
    var curve: CGFloat

    var animatableData: CGFloat {
        get { curve }
        set { curve = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY),
                          control: CGPoint(x: rect.midX, y: rect.midY + curve * rect.height))
        return path
    }
}

/// Speech bubble with a tail pointing down toward his head.
struct BubbleShape: Shape {
    var cornerRadius: CGFloat = 12
    var tailWidth: CGFloat = 14
    var tailHeight: CGFloat = 9

    func path(in rect: CGRect) -> Path {
        let body = CGRect(x: rect.minX, y: rect.minY,
                          width: rect.width, height: max(0, rect.height - tailHeight))
        var path = Path(roundedRect: body, cornerRadius: cornerRadius, style: .continuous)

        let tailCentre = body.minX + body.width * 0.42
        path.move(to: CGPoint(x: tailCentre - tailWidth / 2, y: body.maxY - 1))
        path.addLine(to: CGPoint(x: tailCentre + tailWidth / 2, y: body.maxY - 1))
        path.addQuadCurve(to: CGPoint(x: tailCentre - tailWidth / 2 + 2, y: rect.maxY),
                          control: CGPoint(x: tailCentre + tailWidth / 4, y: body.maxY + tailHeight * 0.6))
        path.closeSubpath()
        return path
    }
}
