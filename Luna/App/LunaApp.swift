import SwiftUI
#if os(iOS)
import ARKit
#endif

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
    @Published var guidedTourStep: GuidedTourStep?
    @Published var guidedTourBodyID: String?
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

        if userProfile.hasCompletedOnboarding && !userProfile.hasCompletedFirstRunTour {
            startFirstRunTour()
        }
    }

    var isGuidedTourActive: Bool {
        guidedTourStep != nil
    }

    var canUseARForGuidedTour: Bool {
#if os(iOS)
        ARWorldTrackingConfiguration.isSupported
#else
        false
#endif
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
        userProfile.hasCompletedFirstRunTour = false
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
        selectedTab = .home
        startFirstRunTour()
    }

    func startFirstRunTour() {
        guidedTourBodyID = nil
        selectedTab = .home
        guidedTourStep = .homeWelcome
    }

    func restartTour() {
        Haptics.selection()
        startFirstRunTour()
    }

    func advanceTour() {
        guard let step = guidedTourStep else { return }

        Haptics.selection()

        switch step {
        case .homeWelcome:
            guidedTourStep = .homeExplore
        case .homeExplore:
            selectedTab = .solarSystem
            guidedTourStep = .exploreCategories
        case .exploreCategories:
            guidedTourStep = .exploreBody
        case .exploreBody:
            guidedTourBodyID = defaultGuidedTourBody?.id
            guidedTourStep = .bodyDetailExperience
        case .bodyDetailExperience:
            guidedTourBodyID = nil
            selectedTab = .arExperience
            guidedTourStep = .experienceScene
        case .experienceScene:
            guidedTourStep = .experienceMode
        case .experienceMode:
            guidedTourStep = .experienceControls
        case .experienceControls:
            guidedTourStep = .experiencePlayback
        case .experiencePlayback:
            guidedTourStep = .finish
        case .finish:
            finishTour()
        }
    }

    func skipTour() {
        Haptics.selection()
        finishTour()
    }

    func finishTour() {
        guidedTourStep = nil
        guidedTourBodyID = nil
        userProfile.hasCompletedFirstRunTour = true
        saveUserProfile()
    }

    func defaultBodyForGuidedTour() -> CelestialBody? {
        defaultGuidedTourBody
    }

    func resetOnboarding() {
        do {
            userProfile = try userProfileRepository.resetOnboarding()
            selectedTab = .home
            guidedTourStep = nil
            guidedTourBodyID = nil
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
            guidedTourStep = nil
            guidedTourBodyID = nil
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

    private var defaultGuidedTourBody: CelestialBody? {
        celestialBodies.first { $0.id == "earth" }
            ?? celestialBodies.first { $0.type == .planet }
            ?? celestialBodies.sorted { $0.displayOrder < $1.displayOrder }.first
    }
}

enum GuidedTourStep: String, CaseIterable, Identifiable {
    case homeWelcome
    case homeExplore
    case exploreCategories
    case exploreBody
    case bodyDetailExperience
    case experienceScene
    case experienceMode
    case experienceControls
    case experiencePlayback
    case finish

    var id: String { rawValue }

    var target: GuidedTourTarget {
        switch self {
        case .homeWelcome:
            return .homeOverview
        case .homeExplore:
            return .homeExploreAction
        case .exploreCategories:
            return .exploreCategory
        case .exploreBody:
            return .exploreBody
        case .bodyDetailExperience:
            return .bodyDetailExperience
        case .experienceScene:
            return .experienceScene
        case .experienceMode:
            return .experienceModeToggle
        case .experienceControls:
            return .experienceControls
        case .experiencePlayback:
            return .experiencePlayback
        case .finish:
            return .experienceControls
        }
    }

    var title: String {
        switch self {
        case .homeWelcome:
            return "Start From Home"
        case .homeExplore:
            return "Open Explore"
        case .exploreCategories:
            return "Browse Collections"
        case .exploreBody:
            return "Open A Body"
        case .bodyDetailExperience:
            return "View It In Space"
        case .experienceScene:
            return "Move Through The Scene"
        case .experienceMode:
            return "Switch Modes"
        case .experienceControls:
            return "Tune The Scene"
        case .experiencePlayback:
            return "Play Or Place"
        case .finish:
            return "You Are Ready"
        }
    }

    func message(canUseAR: Bool) -> String {
        switch self {
        case .homeWelcome:
            return "Home is your launch point for featured worlds, daily space content, and quick access to Luna's main areas."
        case .homeExplore:
            return "Use Explore when you want to browse bodies, spacecraft, facts, scale, and distance before opening a full detail page."
        case .exploreCategories:
            return "Collections group planets, moons, satellites, and NASA models so the library stays easy to scan."
        case .exploreBody:
            return "Open a body card to see facts, orbital details, related bodies, and an entry into the immersive view."
        case .bodyDetailExperience:
            return "This button opens an object-specific experience for the selected body."
        case .experienceScene:
            return "Tap a body for quick facts. In visual mode, drag around the scene to inspect the system from different angles."
        case .experienceMode:
            return canUseAR
                ? "Switch between AR mode for placing bodies in your room and Visual mode for the same controls without AR."
                : "AR is not available on this device, but Visual mode gives you the same scale and scene controls."
        case .experienceControls:
            return "Open controls to change scale, simulation date, orbit playback speed, labels, orbit guides, and render detail."
        case .experiencePlayback:
            return canUseAR
                ? "In AR, line up the target and place the scene. In Visual mode, Play animates the orbital simulation."
                : "Use Play to animate the orbital simulation while you explore in Visual mode."
        case .finish:
            return "You can replay this tour later from Settings without resetting onboarding or changing your preferences."
        }
    }

    var primaryButtonTitle: String {
        self == .finish ? "Done" : "Next"
    }

    var progressText: String {
        guard let index = Self.allCases.firstIndex(of: self) else { return "" }
        return "\(index + 1) of \(Self.allCases.count)"
    }
}
