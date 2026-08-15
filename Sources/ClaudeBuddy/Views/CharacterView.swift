import SwiftUI

/// The buddy himself, drawn in a 132 x 144 box.
struct CharacterView: View {
    /// Wrapped animation clock, in seconds.
    let time: Double
    @ObservedObject var state: BuddyState

    var body: some View {
        let mood: Mood = state.mood
        let breath: CGFloat = CGFloat(sin(time * 2 * .pi / mood.breathPeriod))
        let bob: CGFloat = breath * mood.bobAmplitude
        let dragging: Bool = state.isDragging

        // Squash and stretch, anchored at the feet so he never floats.
        let stretch: CGFloat = dragging ? 1.05 : 1 + breath * 0.030
        let widen: CGFloat = dragging ? 0.97 : 1 - breath * 0.022

        ZStack {
            groundShadow(breath: breath, dragging: dragging)

            ZStack {
                feet(dragging: dragging)
                arms(time: time, mood: mood, dragging: dragging)

                ZStack {
                    bodyShell()
                    face(mood: mood, dragging: dragging)
                }
                .scaleEffect(x: widen, y: stretch, anchor: .bottom)

                sparkles(time: time, mood: mood)

                if mood == .sleeping {
                    SleepZs(time: time)
                        .offset(x: 34, y: -46)
                }
            }
            .offset(y: bob)
            .rotationEffect(.degrees(state.tilt), anchor: .bottom)
        }
        .frame(width: Layout.characterSize.width, height: Layout.characterSize.height)
    }

    // MARK: - Pieces

    private func groundShadow(breath: CGFloat, dragging: Bool) -> some View {
        let width: CGFloat = dragging ? 52 : 74 - breath * 4
        return Ellipse()
            .fill(Palette.shadow.opacity(dragging ? 0.10 : 0.18))
            .frame(width: width, height: 12)
            .blur(radius: 3)
            .offset(y: 64)
    }

    private func bodyShell() -> some View {
        ZStack {
            BlobShape()
                .fill(
                    LinearGradient(
                        colors: [Palette.shellTop, Palette.shellMid, Palette.shellBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    BlobShape()
                        .stroke(Palette.shellBottom.opacity(0.35), lineWidth: 1)
                )

            // Glossy top-left highlight.
            Ellipse()
                .fill(Color.white.opacity(0.20))
                .frame(width: 42, height: 24)
                .blur(radius: 6)
                .offset(x: -16, y: -26)
        }
        .frame(width: 100, height: 92)
        .offset(y: 8)
        .shadow(color: Palette.shadow.opacity(0.22), radius: 6, x: 0, y: 3)
    }

    private func face(mood: Mood, dragging: Bool) -> some View {
        let look: CGSize = state.look
        let eyeShift = CGSize(width: look.width * 3.5, height: look.height * 3.0)

        return ZStack {
            EyeView(mood: mood, blinking: state.isBlinking, dragging: dragging, shift: eyeShift)
                .offset(x: -19, y: -2)
            EyeView(mood: mood, blinking: state.isBlinking, dragging: dragging, shift: eyeShift)
                .offset(x: 19, y: -2)

            Ellipse()
                .fill(Palette.blush.opacity(0.22))
                .frame(width: 14, height: 7)
                .offset(x: -33, y: 12)
            Ellipse()
                .fill(Palette.blush.opacity(0.22))
                .frame(width: 14, height: 7)
                .offset(x: 33, y: 12)

            MouthView(mood: mood, dragging: dragging)
                .offset(x: look.width * 1.6, y: 15)
        }
        // Slight parallax so the whole face leans with the gaze.
        .offset(x: look.width * 1.4, y: look.height * 1.2)
    }

    private func feet(dragging: Bool) -> some View {
        let dangle: CGFloat = dragging ? 7 : 0
        return ZStack {
            Ellipse()
                .fill(Palette.shellBottom)
                .frame(width: 24, height: 12)
                .rotationEffect(.degrees(dragging ? -14 : 0))
                .offset(x: -17, y: 52 + dangle)
            Ellipse()
                .fill(Palette.shellBottom)
                .frame(width: 24, height: 12)
                .rotationEffect(.degrees(dragging ? 14 : 0))
                .offset(x: 17, y: 52 + dangle)
        }
    }

    private func arms(time: Double, mood: Mood, dragging: Bool) -> some View {
        // Little nubs that paddle when he is working and flail when picked up.
        let swing: CGFloat = mood.isBusy ? CGFloat(sin(time * 7)) * 16 : CGFloat(sin(time * 1.6)) * 4
        let lift: CGFloat = dragging ? -26 : 0

        return ZStack {
            Capsule()
                .fill(Palette.shellMid)
                .frame(width: 15, height: 26)
                .rotationEffect(.degrees(Double(-swing + lift)), anchor: .top)
                .offset(x: -46, y: 4)
            Capsule()
                .fill(Palette.shellMid)
                .frame(width: 15, height: 26)
                .rotationEffect(.degrees(Double(swing - lift)), anchor: .top)
                .offset(x: 46, y: 4)
        }
        .shadow(color: Palette.shadow.opacity(0.15), radius: 2, y: 1)
    }

    private func sparkles(time: Double, mood: Mood) -> some View {
        let angle: Double = (time * mood.sparkleSpeed).truncatingRemainder(dividingBy: 360)
        let pulse: CGFloat = 1 + CGFloat(sin(time * 3.4)) * (mood.isBusy ? 0.16 : 0.06)
        let orbitOpacity: Double = mood.isBusy ? 0.95 : 0.0
        let orbit: Double = (time * 140).truncatingRemainder(dividingBy: 360)

        return ZStack {
            SparkleShape()
                .fill(Palette.sparkle)
                .frame(width: 24, height: 24)
                .rotationEffect(.degrees(angle))
                .scaleEffect(pulse)
                .shadow(color: Palette.sparkle.opacity(0.7), radius: 6)

            ForEach(0..<2, id: \.self) { index in
                SparkleShape()
                    .fill(Palette.cream)
                    .frame(width: 8, height: 8)
                    .offset(y: -19)
                    .rotationEffect(.degrees(orbit + Double(index) * 180))
                    .opacity(orbitOpacity)
            }
        }
        .offset(y: -56)
    }
}

// MARK: - Eyes

private struct EyeView: View {
    let mood: Mood
    let blinking: Bool
    let dragging: Bool
    let shift: CGSize

    var body: some View {
        if mood == .sleeping {
            // Contented closed arc.
            MouthShape(curve: 0.9)
                .stroke(Palette.ink, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                .frame(width: 13, height: 6)
        } else {
            let width: CGFloat = dragging ? 13 : 12
            let height: CGFloat = dragging ? 16 : 14

            ZStack {
                Ellipse()
                    .fill(Palette.ink)
                    .frame(width: width, height: height)
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 3.6, height: 3.6)
                    .offset(x: 2.4, y: -3.4)
            }
            .offset(shift)
            .scaleEffect(y: blinking ? 0.10 : 1, anchor: .center)
        }
    }
}

// MARK: - Mouth

private struct MouthView: View {
    let mood: Mood
    let dragging: Bool

    var body: some View {
        if dragging || mood == .curious {
            // Surprised little "o".
            Ellipse()
                .fill(Palette.ink)
                .frame(width: 9, height: dragging ? 11 : 9)
        } else {
            MouthShape(curve: curve)
                .stroke(Palette.ink, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                .frame(width: 22, height: 11)
        }
    }

    private var curve: CGFloat {
        switch mood {
        case .idle: return 0.9
        case .curious: return 1.1
        case .working: return 0.7
        case .thinking: return 0.25
        case .sleeping: return 0.5
        }
    }
}

// MARK: - Sleep

private struct SleepZs: View {
    let time: Double

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let phase = ((time * 0.42) + Double(index) * 0.34).truncatingRemainder(dividingBy: 1)
                Text("z")
                    .font(.system(size: 11 + CGFloat(phase) * 4, weight: .bold, design: .rounded))
                    .foregroundColor(Palette.ink.opacity(0.55 * sin(phase * .pi)))
                    .offset(x: CGFloat(phase) * 11, y: CGFloat(-phase) * 24)
            }
        }
    }
}
