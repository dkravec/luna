import SwiftUI
#if os(iOS)
import ARKit
import UIKit
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
    let guidedTour: GuidedTourCoordinator

    @Published var selectedTab: LunaTab = .home
    @Published private(set) var guidedTourStep: GuidedTourStep?
    @Published private(set) var guidedTourCollectionID: String?
    @Published private(set) var guidedTourBodyID: String?
    @Published private(set) var guidedTourPresentationID = UUID()
    @Published private(set) var guidedTourDismissalID: UUID?
    @Published var appearancePreference: AppAppearancePreference = .system
    @Published var dailyFactOffset: Int = 0
    @Published private(set) var userProfile: UserProfile
    @Published private(set) var experiencePreferences: ExperiencePreferences
    @Published private(set) var celestialBodies: [CelestialBody] = []
    @Published private(set) var lastRepositoryError: String?

    var selectedAppIconChoice: AppIconChoice {
#if os(iOS)
        AppIconChoice(iconName: UIApplication.shared.alternateIconName)
#else
        .current
#endif
    }

    init(
        userProfileRepository: UserProfileRepository = CoreDataUserProfileRepository(),
        experiencePreferencesRepository: ExperiencePreferencesRepository = CoreDataExperiencePreferencesRepository(),
        celestialBodyRepository: CelestialBodyRepository = LocalCelestialBodyRepository(),
        guidedTour: GuidedTourCoordinator = GuidedTourCoordinator()
    ) {
        self.userProfileRepository = userProfileRepository
        self.experiencePreferencesRepository = experiencePreferencesRepository
        self.celestialBodyRepository = celestialBodyRepository
        self.guidedTour = guidedTour

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

        configureGuidedTour()
        loadCelestialBodies()
        configureForUITestingIfNeeded()
        configureForScreenshotModeIfNeeded()

        if userProfile.hasCompletedOnboarding && !userProfile.hasCompletedFirstRunTour {
            restoreOrStartFirstRunTour()
        }
    }

    var isGuidedTourActive: Bool {
        guidedTour.isActive
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
        guidedTour.start()
    }

    func restartTour() {
        Haptics.selection()
        startFirstRunTour()
    }

    func refreshDailyFact() {
        Haptics.selection()
        dailyFactOffset += 1
    }

    func setAppIconChoice(_ choice: AppIconChoice) {
#if os(iOS)
        guard UIApplication.shared.supportsAlternateIcons else { return }
        UIApplication.shared.setAlternateIconName(choice.alternateIconName) { [weak self] error in
            if let error {
                DispatchQueue.main.async {
                    self?.lastRepositoryError = error.localizedDescription
                }
            }
        }
#endif
    }

    func advanceTour() {
        if guidedTour.next() {
            Haptics.selection()
        }
    }

    func goBackTour() {
        if guidedTour.back() {
            Haptics.selection()
        }
    }

    func guidedTourTargetTapped(_ target: GuidedTourTarget) -> Bool {
        let didAdvance = guidedTour.targetTapped(target)
        if didAdvance {
            Haptics.selection()
        }
        return didAdvance
    }

    func skipTour() {
        Haptics.selection()
        guidedTour.skip()
    }

    func finishTour() {
        guidedTour.finish()
    }

    var canGoBackTour: Bool {
        guidedTour.canGoBack
    }

    func defaultBodyForGuidedTour() -> CelestialBody? {
        defaultGuidedTourBody
    }

    func defaultCollectionForGuidedTour() -> ExploreCollection? {
        defaultGuidedTourBody?.exploreCollection ?? .solarSystem
    }

    func resetOnboarding() {
        do {
            guidedTour.cancel()
            userProfile = try userProfileRepository.resetOnboarding()
            selectedTab = .home
            lastRepositoryError = nil
        } catch {
            lastRepositoryError = error.localizedDescription
        }
    }

    func resetUserProfile() {
        do {
            guidedTour.cancel()
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

    private func configureForUITestingIfNeeded() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-uiTesting") else { return }

#if os(iOS)
        if arguments.contains("-disableAnimations") {
            UIView.setAnimationsEnabled(false)
        }
#endif

        do {
            if arguments.contains("-resetProfile") {
                userProfile = try userProfileRepository.resetProfile()
                experiencePreferences = try experiencePreferencesRepository.resetPreferences()
                appearancePreference = userProfile.appearancePreference
                selectedTab = .home
                guidedTour.cancel()
            }

            if arguments.contains("-completeOnboarding") {
                userProfile.displayName = "UITest"
                userProfile.hasCompletedOnboarding = true
                userProfile.hasCompletedFirstRunTour = !arguments.contains("-firstRunTourPending")
                experiencePreferences.prefersARMode = false
                saveUserProfile()
                saveExperiencePreferences()
            }

            if arguments.contains("-firstRunTourPending") {
                userProfile.hasCompletedFirstRunTour = false
                saveUserProfile()
            }

            if arguments.contains("-suppressTour") {
                guidedTour.cancel()
                userProfile.hasCompletedFirstRunTour = true
                clearPersistedGuidedTourStep()
                saveUserProfile()
            }

            if arguments.contains("-openSettings") {
                selectedTab = .settings
            }

            lastRepositoryError = nil
        } catch {
            lastRepositoryError = error.localizedDescription
        }
    }

    private func configureForScreenshotModeIfNeeded() {
        guard ScreenshotMode.isEnabled else { return }

        guidedTour.cancel()
        userProfile.displayName = "Luna"
        userProfile.hasCompletedOnboarding = true
        userProfile.hasCompletedFirstRunTour = true
        appearancePreference = .dark
        userProfile.appearancePreference = .dark
        dailyFactOffset = 0

        experiencePreferences.prefersARMode = ScreenshotMode.screen == .arPlacement
        experiencePreferences.sceneScaleProfile = .scaledRecommended
        experiencePreferences.distanceScaleMode = .compressed
        experiencePreferences.objectScaleMode = .relative
        experiencePreferences.distanceCompression = 18
        experiencePreferences.renderDetail = .balanced
        experiencePreferences.orbitPlaybackSpeed = .standard
        experiencePreferences.objectRotationSpeed = .slow
        experiencePreferences.showLabels = true
        experiencePreferences.showOrbits = true

        switch ScreenshotMode.screen {
        case .exploreLibrary:
            selectedTab = .solarSystem
        case .arPlacement, .sceneExperience, .scaleControls:
            selectedTab = .arExperience
        case .home, .apod, .objectDetail, .macMainWindow, .none:
            selectedTab = .home
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

    private func configureGuidedTour() {
        guidedTour.routeHandler = { [weak self] route in
            self?.handleGuidedTourRoute(route)
        }
        guidedTour.defaultCollectionIDProvider = { [weak self] in
            self?.defaultCollectionForGuidedTour()?.id
        }
        guidedTour.defaultBodyIDProvider = { [weak self] in
            self?.defaultGuidedTourBody?.id
        }
        guidedTour.completionHandler = { [weak self] in
            self?.completeGuidedTourPersistence()
        }
        guidedTour.stateDidChange = { [weak self] in
            self?.syncGuidedTourState()
        }
        syncGuidedTourState()
    }

    private func syncGuidedTourState() {
        guidedTourStep = guidedTour.currentStep
        guidedTourCollectionID = guidedTour.pendingCollectionID
        guidedTourBodyID = guidedTour.pendingBodyID
        guidedTourPresentationID = guidedTour.presentationID
        guidedTourDismissalID = guidedTour.dismissalID
        persistGuidedTourStep(guidedTour.currentStep)
    }

    private func handleGuidedTourRoute(_ route: GuidedTourRoute) {
        switch route {
        case .home:
            selectedTab = .home
        case .explore:
            selectedTab = .solarSystem
        case .bodyDetail:
            selectedTab = .solarSystem
        case .experience:
            selectedTab = .arExperience
        case .settings:
            selectedTab = .settings
        }
    }

    private func completeGuidedTourPersistence() {
        userProfile.hasCompletedFirstRunTour = true
        clearPersistedGuidedTourStep()
        saveUserProfile()
    }

    private var defaultGuidedTourBody: CelestialBody? {
        celestialBodies.first { $0.id == "earth" }
            ?? celestialBodies.first { $0.type == .planet }
            ?? celestialBodies.sorted { $0.displayOrder < $1.displayOrder }.first
    }

    private func restoreOrStartFirstRunTour() {
        let restoredStep = persistedGuidedTourStep()
        guidedTour.start(at: restoredStep ?? .homeWelcome)
    }

    private func persistGuidedTourStep(_ step: GuidedTourStep?) {
        guard let step else {
            clearPersistedGuidedTourStep()
            return
        }

        UserDefaults.standard.set(step.rawValue, forKey: Self.persistedGuidedTourStepKey)
    }

    private func persistedGuidedTourStep() -> GuidedTourStep? {
        guard let rawValue = UserDefaults.standard.string(forKey: Self.persistedGuidedTourStepKey) else {
            return nil
        }

        return GuidedTourStep(rawValue: rawValue)
    }

    private func clearPersistedGuidedTourStep() {
        UserDefaults.standard.removeObject(forKey: Self.persistedGuidedTourStepKey)
    }

    private static let persistedGuidedTourStepKey = "Luna.guidedTour.currentStep"
}
