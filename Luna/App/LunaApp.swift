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
            Haptics.configure(isEnabled: profile.hapticsEnabled, intensity: profile.hapticIntensity)
        } catch {
            userProfile = .defaultProfile
            Haptics.configure(
                isEnabled: UserProfile.defaultProfile.hapticsEnabled,
                intensity: UserProfile.defaultProfile.hapticIntensity
            )
            lastRepositoryError = error.localizedDescription
        }

        loadCelestialBodies()
    }

    func setAppearancePreference(_ preference: AppAppearancePreference) {
        appearancePreference = preference
        userProfile.appearancePreference = preference

        saveUserProfile()
    }

    func setPrefersARMode(_ prefersARMode: Bool) {
        userProfile.prefersARMode = prefersARMode
        saveUserProfile()
    }

    func setPreferredScaleMode(_ scaleMode: ScaleMode) {
        userProfile.preferredScaleMode = scaleMode
        saveUserProfile()
    }

    func setShowLabels(_ showLabels: Bool) {
        userProfile.showLabels = showLabels
        saveUserProfile()
    }

    func setShowOrbits(_ showOrbits: Bool) {
        userProfile.showOrbits = showOrbits
        saveUserProfile()
    }

    func setHapticsEnabled(_ isEnabled: Bool) {
        userProfile.hapticsEnabled = isEnabled
        Haptics.configure(isEnabled: isEnabled, intensity: userProfile.hapticIntensity)
        saveUserProfile()
    }

    func setHapticIntensity(_ intensity: HapticIntensity) {
        userProfile.hapticIntensity = intensity
        Haptics.configure(isEnabled: userProfile.hapticsEnabled, intensity: intensity)
        saveUserProfile()
    }

    func completeOnboarding(
        displayName: String?,
        prefersARMode: Bool,
        preferredScaleMode: ScaleMode
    ) {
        userProfile.displayName = displayName
        userProfile.prefersARMode = prefersARMode
        userProfile.preferredScaleMode = preferredScaleMode
        userProfile.hasCompletedOnboarding = true

        saveUserProfile()
        selectedTab = prefersARMode ? .arExperience : .solarSystem
    }

    func resetOnboarding() {
        do {
            userProfile = try userProfileRepository.resetOnboarding()
            selectedTab = .home
            lastRepositoryError = nil
        } catch {
            lastRepositoryError = error.localizedDescription
        }
    }

    func resetUserProfile() {
        do {
            userProfile = try userProfileRepository.resetProfile()
            appearancePreference = userProfile.appearancePreference
            Haptics.configure(isEnabled: userProfile.hapticsEnabled, intensity: userProfile.hapticIntensity)
            selectedTab = .home
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

    private func saveUserProfile() {
        do {
            try userProfileRepository.save(userProfile)
            lastRepositoryError = nil
        } catch {
            lastRepositoryError = error.localizedDescription
        }
    }
}
