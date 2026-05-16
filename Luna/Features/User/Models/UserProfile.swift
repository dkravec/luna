import Foundation

struct UserProfile: Identifiable, Equatable {
    var id: UUID
    var displayName: String?
    var hasCompletedOnboarding: Bool
    var appearancePreference: AppAppearancePreference
    var hapticsEnabled: Bool
    var hapticIntensity: HapticIntensity

    static let defaultProfile = UserProfile(
        id: UUID(),
        displayName: nil,
        hasCompletedOnboarding: false,
        appearancePreference: .system,
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
