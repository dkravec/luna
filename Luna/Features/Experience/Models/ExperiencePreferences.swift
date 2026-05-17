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
    var sceneScaleProfile: SceneScaleProfile
    var distanceScaleMode: DistanceScaleMode
    var objectScaleMode: ObjectScaleMode
    var distanceCompression: Double
    var renderDetail: SceneRenderDetail
    var orbitPlaybackSpeed: OrbitPlaybackSpeed
    var objectRotationSpeed: ObjectRotationSpeed
    var showLabels: Bool
    var showOrbits: Bool

    static let defaults = ExperiencePreferences(
        id: UUID(),
        prefersARMode: true,
        sceneScaleProfile: .scaledRecommended,
        distanceScaleMode: .compressed,
        objectScaleMode: .relative,
        distanceCompression: 30,
        renderDetail: .balanced,
        orbitPlaybackSpeed: .standard,
        objectRotationSpeed: .slow,
        showLabels: true,
        showOrbits: true
    )
}

enum SceneScaleProfile: String, CaseIterable, Codable, Identifiable {
    case scaledRecommended
    case uniform
    case trueSize
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scaledRecommended:
            return "Scaled (Recommended)"
        case .uniform:
            return "Uniform"
        case .trueSize:
            return "True Size"
        case .custom:
            return "Custom"
        }
    }

    var subtitle: String {
        switch self {
        case .scaledRecommended:
            return "Compressed distances with readable relative planet sizes."
        case .uniform:
            return "Readable equal-size bodies with compressed orbital spacing."
        case .trueSize:
            return "True radius ratios and true orbital distances; tiny bodies may be hard to see."
        case .custom:
            return "Tune distance, size, compression, and render detail manually."
        }
    }

    var defaultDistanceScaleMode: DistanceScaleMode {
        switch self {
        case .scaledRecommended, .uniform, .custom:
            return .compressed
        case .trueSize:
            return .trueScale
        }
    }

    var defaultObjectScaleMode: ObjectScaleMode {
        switch self {
        case .scaledRecommended, .custom:
            return .relative
        case .uniform:
            return .uniform
        case .trueSize:
            return .trueScale
        }
    }
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
            return "Compressed Distance"
        case .trueScale:
            return "True Distance"
        }
    }

    var subtitle: String {
        switch self {
        case .educational:
            return "Equal spacing for comparison; not physically proportional."
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
            return "Uses real radius ratios with no visual floor."
        }
    }

    static func fromLegacyMultiplier(_ multiplier: Double) -> ObjectScaleMode {
        multiplier <= 2 ? .uniform : .relative
    }
}

enum SceneRenderDetail: String, CaseIterable, Codable, Identifiable {
    case low
    case balanced
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low:
            return "Low"
        case .balanced:
            return "Balanced"
        case .high:
            return "High"
        }
    }

    var subtitle: String {
        switch self {
        case .low:
            return "Fewer orbit samples and simpler spheres for older devices."
        case .balanced:
            return "Good visual quality without wasting render work."
        case .high:
            return "More orbit samples and smoother bodies."
        }
    }

    var orbitSampleCount: Int {
        switch self {
        case .low:
            return 72
        case .balanced:
            return 144
        case .high:
            return 288
        }
    }

    var planetSegmentCount: Int {
        switch self {
        case .low:
            return 32
        case .balanced:
            return 48
        case .high:
            return 72
        }
    }

    var starSegmentCount: Int {
        switch self {
        case .low:
            return 48
        case .balanced:
            return 64
        case .high:
            return 96
        }
    }

    var arOrbitStride: Int {
        switch self {
        case .low:
            return 10
        case .balanced:
            return 6
        case .high:
            return 4
        }
    }

    var usesFullBackgroundTexture: Bool {
        self == .high
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
