import CoreGraphics

enum Mood: Equatable {
    /// Nothing much going on.
    case idle
    /// The pointer is nearby, so he perks up.
    case curious
    /// A `claude` process is alive.
    case working
    /// A `claude` process is alive and burning CPU.
    case thinking
    /// The pointer has not moved in a while.
    case sleeping

    /// How often the animation timeline ticks. Sleeping barely redraws.
    var frameInterval: Double {
        switch self {
        case .sleeping: return 1.0 / 8.0
        case .idle: return 1.0 / 30.0
        case .curious: return 1.0 / 45.0
        case .working, .thinking: return 1.0 / 60.0
        }
    }

    /// Degrees per second for the sparkle above his head.
    var sparkleSpeed: Double {
        switch self {
        case .sleeping: return 6
        case .idle: return 22
        case .curious: return 40
        case .working: return 150
        case .thinking: return 300
        }
    }

    /// Seconds per breath cycle.
    var breathPeriod: Double {
        switch self {
        case .sleeping: return 4.4
        case .idle: return 2.8
        case .curious: return 2.2
        case .working: return 1.6
        case .thinking: return 1.1
        }
    }

    /// How far he bobs, in points.
    var bobAmplitude: CGFloat {
        switch self {
        case .sleeping: return 0.8
        case .idle: return 1.8
        case .curious: return 2.6
        case .working: return 3.4
        case .thinking: return 4.2
        }
    }

    var isBusy: Bool { self == .working || self == .thinking }
}
