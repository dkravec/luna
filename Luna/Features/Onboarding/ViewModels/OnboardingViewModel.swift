import Foundation

final class OnboardingViewModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case welcome
        case profile
        case viewingMode
        case scaleMode

        var isFirst: Bool {
            self == Step.allCases.first
        }

        var isLast: Bool {
            self == Step.allCases.last
        }
    }

    @Published var step: Step = .welcome
    @Published var displayName = ""
    @Published var prefersARMode = true
    @Published var sceneScaleProfile: SceneScaleProfile = .scaledRecommended
    @Published var distanceScaleMode: DistanceScaleMode = .compressed
    @Published var objectScaleMode: ObjectScaleMode = .relative
    @Published var distanceCompression: Double = 30

    var primaryButtonTitle: String {
        step.isLast ? "Start Exploring" : "Continue"
    }

    var trimmedDisplayName: String? {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var progressText: String {
        "\(step.rawValue + 1) of \(Step.allCases.count)"
    }

    func advance() {
        guard let nextStep = Step(rawValue: step.rawValue + 1) else { return }
        step = nextStep
    }

    func goBack() {
        guard let previousStep = Step(rawValue: step.rawValue - 1) else { return }
        step = previousStep
    }
}
