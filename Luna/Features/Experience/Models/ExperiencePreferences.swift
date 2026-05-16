import Foundation

struct ExperiencePreferences: Identifiable, Equatable {
    var id: UUID
    var prefersARMode: Bool
    var distanceScaleMode: DistanceScaleMode
    var objectScaleMode: ObjectScaleMode
    var distanceCompression: Double
    var orbitPlaybackSpeed: OrbitPlaybackSpeed
    var showLabels: Bool
    var showOrbits: Bool

    static let defaults = ExperiencePreferences(
        id: UUID(),
        prefersARMode: true,
        distanceScaleMode: .educational,
        objectScaleMode: .relative,
        distanceCompression: 30,
        orbitPlaybackSpeed: .standard,
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
            return "Uses the closest practical accurate distance mapping."
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
            return "Preserves the strongest practical real-radius differences."
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
