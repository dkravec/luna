import Foundation

enum GuidedTourTarget: String, Hashable {
    case homeOverview
    case homeExploreAction
    case homeExperienceAction
    case exploreCategory
    case exploreBody
    case bodyDetailExperience
    case experienceScene
    case experienceModeToggle
    case experienceControls
    case experiencePlayback

    var accessibilityIdentifier: String {
        switch self {
        case .homeOverview:
            return "tourTarget.home.overview"
        case .homeExploreAction:
            return "tourTarget.home.explore"
        case .homeExperienceAction:
            return "tourTarget.home.experience"
        case .exploreCategory:
            return "tourTarget.explore.category"
        case .exploreBody:
            return "tourTarget.explore.body"
        case .bodyDetailExperience:
            return "tourTarget.bodyDetail.experience"
        case .experienceScene:
            return "tourTarget.experience.scene"
        case .experienceModeToggle:
            return "tourTarget.experience.mode"
        case .experienceControls:
            return "tourTarget.experience.controls"
        case .experiencePlayback:
            return "tourTarget.experience.playback"
        }
    }
}

enum GuidedTourRoute: Equatable {
    case home
    case explore
    case bodyDetail(String?)
    case experience
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

    var route: GuidedTourRoute {
        switch self {
        case .homeWelcome, .homeExplore:
            return .home
        case .exploreCategories, .exploreBody:
            return .explore
        case .bodyDetailExperience:
            return .bodyDetail(nil)
        case .experienceScene, .experienceMode, .experienceControls, .experiencePlayback, .finish:
            return .experience
        }
    }

    var advancesFromTargetTap: Bool {
        switch self {
        case .homeExplore, .exploreCategories, .exploreBody, .bodyDetailExperience, .experienceScene, .experienceMode, .experienceControls, .experiencePlayback:
            return true
        case .homeWelcome, .finish:
            return false
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
            return "Try dragging or tapping in the visual scene. Next always moves on when you are ready."
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
        switch self {
        case .bodyDetailExperience:
            return "Open Experience"
        case .finish:
            return "Done"
        default:
            return "Next"
        }
    }

    var progressText: String {
        guard let index = Self.allCases.firstIndex(of: self) else { return "" }
        return "\(index + 1) of \(Self.allCases.count)"
    }
}

final class GuidedTourCoordinator: ObservableObject {
    @Published private(set) var currentStep: GuidedTourStep?
    @Published private(set) var pendingBodyID: String?
    @Published private(set) var presentationID = UUID()
    @Published private(set) var dismissalID: UUID?

    var routeHandler: (GuidedTourRoute) -> Void = { _ in }
    var completionHandler: () -> Void = {}
    var defaultBodyIDProvider: () -> String? = { nil }
    var stateDidChange: () -> Void = {}

    private var isTransitionLocked = false

    var isActive: Bool {
        currentStep != nil
    }

    var canGoBack: Bool {
        guard let currentStep else { return false }
        return previousStep(before: currentStep) != nil
    }

    func start() {
        isTransitionLocked = false
        pendingBodyID = nil
        presentationID = UUID()
        dismissalID = nil
        routeHandler(.home)
        currentStep = .homeWelcome
        stateDidChange()
    }

    @discardableResult
    func next() -> Bool {
        guard let currentStep, beginTransition() else { return false }

        if let nextStep = nextStep(after: currentStep) {
            setStep(nextStep)
        } else {
            finish()
        }

        return true
    }

    @discardableResult
    func back() -> Bool {
        guard let currentStep,
              let previousStep = previousStep(before: currentStep),
              beginTransition()
        else {
            return false
        }

        setStep(previousStep)
        return true
    }

    @discardableResult
    func targetTapped(_ target: GuidedTourTarget) -> Bool {
        guard let currentStep,
              currentStep.target == target,
              currentStep.advancesFromTargetTap
        else {
            return false
        }

        return next()
    }

    func skip() {
        finish()
    }

    func cancel() {
        isTransitionLocked = false
        currentStep = nil
        pendingBodyID = nil
        presentationID = UUID()
        dismissalID = UUID()
        stateDidChange()
    }

    func finish() {
        isTransitionLocked = false
        currentStep = nil
        pendingBodyID = nil
        presentationID = UUID()
        dismissalID = UUID()
        completionHandler()
        stateDidChange()
    }

    private func setStep(_ step: GuidedTourStep) {
        let bodyID = step == .bodyDetailExperience ? defaultBodyIDProvider() : nil
        pendingBodyID = bodyID

        switch step.route {
        case .bodyDetail:
            routeHandler(.bodyDetail(bodyID))
        default:
            routeHandler(step.route)
        }

        currentStep = step
        stateDidChange()
    }

    private func beginTransition() -> Bool {
        guard !isTransitionLocked else { return false }

        isTransitionLocked = true
        DispatchQueue.main.async { [weak self] in
            self?.isTransitionLocked = false
        }
        return true
    }

    private func nextStep(after step: GuidedTourStep) -> GuidedTourStep? {
        guard let index = GuidedTourStep.allCases.firstIndex(of: step) else { return nil }
        let nextIndex = GuidedTourStep.allCases.index(after: index)
        guard nextIndex < GuidedTourStep.allCases.endIndex else { return nil }
        return GuidedTourStep.allCases[nextIndex]
    }

    private func previousStep(before step: GuidedTourStep) -> GuidedTourStep? {
        guard let index = GuidedTourStep.allCases.firstIndex(of: step),
              index > GuidedTourStep.allCases.startIndex
        else {
            return nil
        }

        let previousIndex = GuidedTourStep.allCases.index(before: index)
        return GuidedTourStep.allCases[previousIndex]
    }
}
