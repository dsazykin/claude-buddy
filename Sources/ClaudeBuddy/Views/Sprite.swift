import SwiftUI

/// Pixel art, written as text so the character stays editable by hand.
///
/// `X` is body, `o` is ink (eyes and mouth), `.` is empty. Every frame must be
/// `columns` x `rows`, or the character will jump between frames.
///
/// `stand` and `eyesOpen` are traced cell for cell from the reference artwork;
/// the other frames are drawn to match it.
enum Sprite {
    /// Cells across and down. All character frames share this grid.
    static let columns = 12
    static let rows = 8

    /// Standing still. Arms out at rows 2-3, four legs below.
    static let stand = [
        "..XXXXXXXX..",
        "..XXXXXXXX..",
        "XXXXXXXXXXXX",
        "XXXXXXXXXXXX",
        "..XXXXXXXX..",
        "..XXXXXXXX..",
        "..X.X..X.X..",
        "..X.X..X.X.."
    ]

    /// Mid-stride: the inner pair of legs is planted, the outer pair lifted.
    /// Alternating these two is the walk cycle.
    static let walkA = [
        "..XXXXXXXX..",
        "..XXXXXXXX..",
        "XXXXXXXXXXXX",
        "XXXXXXXXXXXX",
        "..XXXXXXXX..",
        "..XXXXXXXX..",
        "..X.X..X.X..",
        "..X....X...."
    ]

    static let walkB = [
        "..XXXXXXXX..",
        "..XXXXXXXX..",
        "XXXXXXXXXXXX",
        "XXXXXXXXXXXX",
        "..XXXXXXXX..",
        "..XXXXXXXX..",
        "..X.X..X.X..",
        "....X....X.."
    ]

    /// All four feet off the ground, tucked under him.
    static let airborne = [
        "..XXXXXXXX..",
        "..XXXXXXXX..",
        "XXXXXXXXXXXX",
        "XXXXXXXXXXXX",
        "..XXXXXXXX..",
        "..XXXXXXXX..",
        "..XXXXXXXX..",
        "............"
    ]

    /// Legs splayed, for when he is picked up.
    static let dangling = [
        "..XXXXXXXX..",
        "..XXXXXXXX..",
        "XXXXXXXXXXXX",
        "XXXXXXXXXXXX",
        "..XXXXXXXX..",
        "..XXXXXXXX..",
        "..X.X..X.X..",
        ".X..X..X..X."
    ]

    // MARK: - Eyes
    //
    // Their own layer over the body, so blinking and glancing do not each need
    // a whole extra body frame.

    /// One cell per eye, as in the reference.
    static let eyesOpen = [
        "............",
        "...o....o...",
        "............",
        "............",
        "............",
        "............",
        "............",
        "............"
    ]

    /// Shut: wider and flatter than open, which is what reads as closed at this
    /// size. Used for blinking, sleeping and yawning.
    static let eyesShut = [
        "............",
        "..oo....oo..",
        "............",
        "............",
        "............",
        "............",
        "............",
        "............"
    ]

    /// An open mouth, only used mid-yawn.
    static let mouthOpen = [
        "............",
        "............",
        "............",
        ".....oo.....",
        ".....oo.....",
        "............",
        "............",
        "............"
    ]

    /// A four-cell twinkle, for when a Claude Code session is working.
    static let sparkle = [
        ".o.",
        "ooo",
        ".o."
    ]

    /// A sleeping "z", drawn on its own 3 x 5 grid.
    static let sleepZ = [
        "ooo",
        "..o",
        ".o.",
        "o..",
        "ooo"
    ]
}

/// Fills every cell of a pixel grid matching `ink`, as one path of squares.
///
/// Cells are laid out on a shared grid derived from `Sprite.columns/rows`, so
/// the body, eye and mouth layers line up regardless of which frame is showing.
struct PixelShape: Shape {
    let rows: [String]
    /// Which character to fill: `X` for body, `o` for ink.
    var ink: Character = "X"
    /// Grid the cells are measured against. Defaults to the character grid.
    var columns: Int = Sprite.columns
    var lines: Int = Sprite.rows

    func path(in rect: CGRect) -> Path {
        let cell = min(rect.width / CGFloat(columns), rect.height / CGFloat(lines))
        let originX = rect.midX - cell * CGFloat(columns) / 2
        let originY = rect.midY - cell * CGFloat(lines) / 2

        var path = Path()
        for (row, line) in rows.enumerated() {
            for (column, character) in line.enumerated() where character == ink {
                path.addRect(
                    CGRect(x: originX + CGFloat(column) * cell,
                           y: originY + CGFloat(row) * cell,
                           // A hair of overlap, so neighbouring cells do not
                           // show a seam when the whole sprite is scaled.
                           width: cell + 0.4,
                           height: cell + 0.4)
                )
            }
        }
        return path
    }
}
