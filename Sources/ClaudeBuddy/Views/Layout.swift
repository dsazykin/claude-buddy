import CoreGraphics

/// Geometry for the buddy, in unscaled base points. The panel is this size
/// multiplied by the preferred scale; the SwiftUI content is laid out at base
/// size and scaled about its centre, so any base rect maps into panel
/// coordinates by simple multiplication.
enum Layout {
    static let basePanelSize = CGSize(width: 240, height: 250)

    /// Top strip reserved for the speech bubble.
    static let bubbleAreaHeight: CGFloat = 106
    static let bubbleMaxWidth: CGFloat = 208

    /// Bottom strip holding the character itself.
    static let characterSize = CGSize(width: 132, height: 144)

    /// Clickable silhouette, in AppKit panel coordinates (origin bottom-left).
    static let characterHitRect = CGRect(x: 56, y: 0, width: 128, height: 140)

    /// Clickable area while a speech bubble is on screen.
    static let bubbleHitRect = CGRect(x: 14,
                                      y: basePanelSize.height - bubbleAreaHeight,
                                      width: basePanelSize.width - 28,
                                      height: bubbleAreaHeight)

    static func panelSize(for scale: CGFloat) -> CGSize {
        CGSize(width: basePanelSize.width * scale, height: basePanelSize.height * scale)
    }

    static func scaled(_ rect: CGRect, _ scale: CGFloat) -> CGRect {
        CGRect(x: rect.origin.x * scale,
               y: rect.origin.y * scale,
               width: rect.width * scale,
               height: rect.height * scale)
    }
}
