import SwiftUI

@main
struct LunaApp: App {
    @StateObject private var appState = LunaAppState()

    var body: some Scene {
        WindowGroup {
            LunaRootView()
                .environmentObject(appState)
                .preferredColorScheme(appState.appearancePreference.colorScheme)
        }
    }
}

final class LunaAppState: ObservableObject {
    @Published var selectedTab: LunaTab = .home
    @Published var appearancePreference: AppAppearancePreference = .system
}

enum AppAppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
