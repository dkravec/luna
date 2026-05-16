import Foundation

struct UserProfile: Identifiable, Equatable {
    var id: UUID
    var displayName: String?
    var hasCompletedOnboarding: Bool
    var preferredScaleMode: ScaleMode
    var distanceCompression: Double
    var planetSizeMultiplier: Double
    var prefersARMode: Bool
    var appearancePreference: AppAppearancePreference
    var showLabels: Bool
    var showOrbits: Bool
    var hapticsEnabled: Bool
    var hapticIntensity: HapticIntensity

    static let defaultProfile = UserProfile(
        id: UUID(),
        displayName: nil,
        hasCompletedOnboarding: false,
        preferredScaleMode: .educational,
        distanceCompression: 30,
        planetSizeMultiplier: 5,
        prefersARMode: true,
        appearancePreference: .system,
        showLabels: true,
        showOrbits: true,
        hapticsEnabled: true,
        hapticIntensity: .heavy
    )
}

enum HapticIntensity: String, CaseIterable, Codable, Identifiable {
    case light
    case medium
    case heavy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light:
            return "Light"
        case .medium:
            return "Medium"
        case .heavy:
            return "Heavy"
        }
    }
}

enum ScaleMode: String, CaseIterable, Codable, Identifiable {
    case trueDistance
    case compressedDistance
    case educational
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trueDistance:
            return "True Distance"
        case .compressedDistance:
            return "Compressed Distance"
        case .educational:
            return "Educational"
        case .custom:
            return "Custom"
        }
    }
}

enum PlanetSizeMultiplier: Double, CaseIterable, Identifiable {
    case one = 1
    case two = 2
    case five = 5
    case ten = 10
    case twenty = 20

    var id: Double { rawValue }

    var title: String {
        "\(Int(rawValue))x"
    }
}
