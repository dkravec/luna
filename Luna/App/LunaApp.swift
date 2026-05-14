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
    let userProfileRepository: UserProfileRepository
    let celestialBodyRepository: CelestialBodyRepository

    @Published var selectedTab: LunaTab = .home
    @Published var appearancePreference: AppAppearancePreference = .system
    @Published private(set) var userProfile: UserProfile
    @Published private(set) var celestialBodies: [CelestialBody] = []
    @Published private(set) var lastRepositoryError: String?

    init(
        userProfileRepository: UserProfileRepository = CoreDataUserProfileRepository(),
        celestialBodyRepository: CelestialBodyRepository = LocalCelestialBodyRepository()
    ) {
        self.userProfileRepository = userProfileRepository
        self.celestialBodyRepository = celestialBodyRepository

        do {
            let profile = try userProfileRepository.fetchOrCreateProfile()
            userProfile = profile
            appearancePreference = profile.appearancePreference
        } catch {
            userProfile = .defaultProfile
            lastRepositoryError = error.localizedDescription
        }

        loadCelestialBodies()
    }

    func setAppearancePreference(_ preference: AppAppearancePreference) {
        appearancePreference = preference
        userProfile.appearancePreference = preference

        do {
            try userProfileRepository.save(userProfile)
            lastRepositoryError = nil
        } catch {
            lastRepositoryError = error.localizedDescription
        }
    }

    func resetOnboarding() {
        do {
            userProfile = try userProfileRepository.resetOnboarding()
            lastRepositoryError = nil
        } catch {
            lastRepositoryError = error.localizedDescription
        }
    }

    func loadCelestialBodies() {
        do {
            celestialBodies = try celestialBodyRepository.fetchBodies()
            lastRepositoryError = nil
        } catch {
            celestialBodies = []
            lastRepositoryError = error.localizedDescription
        }
    }
}
