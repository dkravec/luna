import SwiftUI

enum LunaTab: String, CaseIterable, Identifiable {
    case home
    case solarSystem
    case arExperience
    case settings

    var id: String { rawValue }

    static var primaryTabs: [LunaTab] {
        [.home, .solarSystem, .arExperience]
    }

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .solarSystem:
            return "Explore"
        case .arExperience:
            return "AR Experience"
        case .settings:
            return "Settings"
        }
    }

    var shortTitle: String {
        switch self {
        case .home:
            return "Home"
        case .solarSystem:
            return "Explore"
        case .arExperience:
            return "AR"
        case .settings:
            return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            return "house"
        case .solarSystem:
            return "sun.max"
        case .arExperience:
            return "arkit"
        case .settings:
            return "gearshape"
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .home:
            HomeView()
        case .solarSystem:
            ExploreView()
        case .arExperience:
            ExperienceView()
        case .settings:
            SettingsView()
        }
    }
}
