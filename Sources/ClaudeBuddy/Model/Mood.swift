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

    /// Radians per second through the walk cycle: how fast his feet alternate.
    /// A brisker mood walks with a quicker step.
    var stepRate: Double {
        switch self {
        case .sleeping: return 5
        case .idle: return 8
        case .curious: return 9
        case .working: return 10
        case .thinking: return 11
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
