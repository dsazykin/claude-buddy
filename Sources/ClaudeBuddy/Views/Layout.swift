import CoreGraphics

/// Geometry for the buddy, in base points.
///
/// The character is drawn in a fixed box and scaled by the preferred size; the
/// speech bubble deliberately is *not* scaled, so a small buddy still has
/// readable speech. The panel is therefore a fixed width with a character strip
/// whose height follows the scale, and a bubble strip that sits above him — or
/// below, when he is perched too high for a bubble to fit overhead.
enum Layout {
    /// Fixed panel width, wide enough for the widest bubble.
    static let panelWidth: CGFloat = 224

    /// Strip reserved for the speech bubble, at whichever end it is on.
    static let bubbleAreaHeight: CGFloat = 86
    static let bubbleMaxWidth: CGFloat = 200

    /// The character's own drawing box, before scaling. Wider than the sprite
    /// is tall, and taller than the sprite, leaving room above him for sparkles
    /// and sleep "z"s.
    static let characterSize = CGSize(width: 132, height: 128)

    static func characterBox(for scale: CGFloat) -> CGSize {
        CGSize(width: characterSize.width * scale, height: characterSize.height * scale)
    }

    static func panelSize(for scale: CGFloat) -> CGSize {
        CGSize(width: panelWidth, height: bubbleAreaHeight + characterSize.height * scale)
    }

    /// Clickable silhouette, in AppKit panel coordinates (origin bottom-left).
    static func characterHitRect(for scale: CGFloat, bubbleBelow: Bool) -> CGRect {
        let box = characterBox(for: scale)
        return CGRect(x: (panelWidth - box.width) / 2,
                      y: bubbleBelow ? bubbleAreaHeight : 0,
                      width: box.width,
                      height: box.height)
    }

    /// Clickable area while a speech bubble is on screen.
    static func bubbleHitRect(for scale: CGFloat, bubbleBelow: Bool) -> CGRect {
        CGRect(x: 10,
               y: bubbleBelow ? 0 : characterBox(for: scale).height,
               width: panelWidth - 20,
               height: bubbleAreaHeight)
    }

    /// Where his eyes sit inside the panel, in AppKit coordinates.
    static func eyePoint(for scale: CGFloat, bubbleBelow: Bool) -> CGPoint {
        let box = characterHitRect(for: scale, bubbleBelow: bubbleBelow)
        return CGPoint(x: box.midX, y: box.minY + box.height * 0.52)
    }
}
