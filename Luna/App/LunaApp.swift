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
    let experiencePreferencesRepository: ExperiencePreferencesRepository
    let celestialBodyRepository: CelestialBodyRepository

    @Published var selectedTab: LunaTab = .home
    @Published var appearancePreference: AppAppearancePreference = .system
    @Published private(set) var userProfile: UserProfile
    @Published private(set) var experiencePreferences: ExperiencePreferences
    @Published private(set) var celestialBodies: [CelestialBody] = []
    @Published private(set) var lastRepositoryError: String?

    init(
        userProfileRepository: UserProfileRepository = CoreDataUserProfileRepository(),
        experiencePreferencesRepository: ExperiencePreferencesRepository = CoreDataExperiencePreferencesRepository(),
        celestialBodyRepository: CelestialBodyRepository = LocalCelestialBodyRepository()
    ) {
        self.userProfileRepository = userProfileRepository
        self.experiencePreferencesRepository = experiencePreferencesRepository
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

        do {
            experiencePreferences = try experiencePreferencesRepository.fetchOrCreatePreferences()
        } catch {
            experiencePreferences = .defaults
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
        experiencePreferences.prefersARMode = prefersARMode
        saveExperiencePreferences()
    }

    func setSceneScaleProfile(_ profile: SceneScaleProfile) {
        experiencePreferences.sceneScaleProfile = profile
        if profile != .custom {
            experiencePreferences.distanceScaleMode = profile.defaultDistanceScaleMode
            experiencePreferences.objectScaleMode = profile.defaultObjectScaleMode
        }
        saveExperiencePreferences()
    }

    func setDistanceScaleMode(_ scaleMode: DistanceScaleMode) {
        experiencePreferences.sceneScaleProfile = .custom
        experiencePreferences.distanceScaleMode = scaleMode
        saveExperiencePreferences()
    }

    func setDistanceCompression(_ distanceCompression: Double) {
        experiencePreferences.sceneScaleProfile = .custom
        experiencePreferences.distanceCompression = ExperienceSceneSettings.clampedDistanceCompression(distanceCompression)
        saveExperiencePreferences()
    }

    func setObjectScaleMode(_ objectScaleMode: ObjectScaleMode) {
        experiencePreferences.sceneScaleProfile = .custom
        experiencePreferences.objectScaleMode = objectScaleMode
        saveExperiencePreferences()
    }

    func setRenderDetail(_ renderDetail: SceneRenderDetail) {
        experiencePreferences.renderDetail = renderDetail
        saveExperiencePreferences()
    }

    func setOrbitPlaybackSpeed(_ speed: OrbitPlaybackSpeed) {
        experiencePreferences.orbitPlaybackSpeed = speed
        saveExperiencePreferences()
    }

    func setObjectRotationSpeed(_ speed: ObjectRotationSpeed) {
        experiencePreferences.objectRotationSpeed = speed
        saveExperiencePreferences()
    }

    func setShowLabels(_ showLabels: Bool) {
        experiencePreferences.showLabels = showLabels
        saveExperiencePreferences()
    }

    func setShowOrbits(_ showOrbits: Bool) {
        experiencePreferences.showOrbits = showOrbits
        saveExperiencePreferences()
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
        sceneScaleProfile: SceneScaleProfile,
        distanceScaleMode: DistanceScaleMode,
        objectScaleMode: ObjectScaleMode,
        distanceCompression: Double
    ) {
        userProfile.displayName = displayName
        userProfile.hasCompletedOnboarding = true
        experiencePreferences.prefersARMode = prefersARMode
        experiencePreferences.sceneScaleProfile = sceneScaleProfile
        experiencePreferences.distanceScaleMode = sceneScaleProfile == .custom
            ? distanceScaleMode
            : sceneScaleProfile.defaultDistanceScaleMode
        experiencePreferences.objectScaleMode = sceneScaleProfile == .custom
            ? objectScaleMode
            : sceneScaleProfile.defaultObjectScaleMode
        experiencePreferences.distanceCompression = ExperienceSceneSettings.clampedDistanceCompression(distanceCompression)

        saveUserProfile()
        saveExperiencePreferences()
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
            experiencePreferences = try experiencePreferencesRepository.resetPreferences()
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

    private func saveExperiencePreferences() {
        do {
            try experiencePreferencesRepository.save(experiencePreferences)
            lastRepositoryError = nil
        } catch {
            lastRepositoryError = error.localizedDescription
        }
    }
}
