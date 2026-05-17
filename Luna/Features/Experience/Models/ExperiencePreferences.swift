import Foundation

enum ARPlacementState: Equatable {
    case unavailable
    case initializing
    case findingSurface
    case ready

    var isReady: Bool {
        self == .ready
    }

    var title: String {
        switch self {
        case .unavailable:
            return "AR Unavailable"
        case .initializing:
            return "Starting AR"
        case .findingSurface:
            return "Find Surface"
        case .ready:
            return "Surface Ready"
        }
    }

    var message: String {
        switch self {
        case .unavailable:
            return "AR is not available on this device."
        case .initializing:
            return "Move your phone slowly so Luna can understand the room."
        case .findingSurface:
            return "Point the target at a detected table or floor surface."
        case .ready:
            return "Place Luna flat on the detected surface."
        }
    }
}

struct ExperiencePreferences: Identifiable, Equatable {
    var id: UUID
    var prefersARMode: Bool
    var distanceScaleMode: DistanceScaleMode
    var objectScaleMode: ObjectScaleMode
    var distanceCompression: Double
    var orbitPlaybackSpeed: OrbitPlaybackSpeed
    var objectRotationSpeed: ObjectRotationSpeed
    var showLabels: Bool
    var showOrbits: Bool

    static let defaults = ExperiencePreferences(
        id: UUID(),
        prefersARMode: true,
        distanceScaleMode: .educational,
        objectScaleMode: .relative,
        distanceCompression: 30,
        orbitPlaybackSpeed: .standard,
        objectRotationSpeed: .slow,
        showLabels: true,
        showOrbits: true
    )
}

enum DistanceScaleMode: String, CaseIterable, Codable, Identifiable {
    case educational
    case compressed
    case trueScale

    var id: String { rawValue }

    var title: String {
        switch self {
        case .educational:
            return "Educational"
        case .compressed:
            return "Compressed"
        case .trueScale:
            return "True Distance"
        }
    }

    var subtitle: String {
        switch self {
        case .educational:
            return "Equal readable spacing for learning and comparison."
        case .compressed:
            return "Keeps relative distance order while pulling bodies closer together."
        case .trueScale:
            return "Uses real distance ratios; objects may be very far apart."
        }
    }

    static func fromLegacyRawValue(_ rawValue: String?) -> DistanceScaleMode {
        switch rawValue {
        case "compressedDistance":
            return .compressed
        case "trueDistance":
            return .trueScale
        default:
            return .educational
        }
    }
}

enum ObjectScaleMode: String, CaseIterable, Codable, Identifiable {
    case uniform
    case relative
    case trueScale

    var id: String { rawValue }

    var title: String {
        switch self {
        case .uniform:
            return "Uniform"
        case .relative:
            return "Relative"
        case .trueScale:
            return "True Size"
        }
    }

    var subtitle: String {
        switch self {
        case .uniform:
            return "Keeps objects close to the same readable size."
        case .relative:
            return "Shows size differences while keeping small objects visible."
        case .trueScale:
            return "Uses real radius ratios with a tiny visibility floor."
        }
    }

    static func fromLegacyMultiplier(_ multiplier: Double) -> ObjectScaleMode {
        multiplier <= 2 ? .uniform : .relative
    }
}

enum OrbitPlaybackSpeed: String, CaseIterable, Codable, Identifiable {
    case slow
    case standard
    case fast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .slow:
            return "Slow"
        case .standard:
            return "Standard"
        case .fast:
            return "Fast"
        }
    }

    var daysPerSecond: Double {
        switch self {
        case .slow:
            return 4
        case .standard:
            return 18
        case .fast:
            return 72
        }
    }
}

enum ObjectRotationSpeed: String, CaseIterable, Codable, Identifiable {
    case off
    case slow
    case standard
    case fast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off:
            return "Off"
        case .slow:
            return "Slow"
        case .standard:
            return "Standard"
        case .fast:
            return "Fast"
        }
    }

    var multiplier: Double {
        switch self {
        case .off:
            return 0
        case .slow:
            return 0.004
        case .standard:
            return 0.010
        case .fast:
            return 0.024
        }
    }
}
