import SwiftUI

struct OnboardingFlowView: View {
    @EnvironmentObject private var appState: LunaAppState
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.section) {
                    progressHeader

                    stepContent
                }
                .screenContentPadding()
            }

            footer
        }
        .appBackground()
    }

    private var progressHeader: some View {
        HStack {
            Text(viewModel.progressText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            if !viewModel.step.isFirst {
                Button("Back") {
                    viewModel.goBack()
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case .welcome:
            WelcomeStepView()
        case .viewingMode:
            ViewingModeStepView(prefersARMode: $viewModel.prefersARMode)
        case .profile:
            ProfileStepView(displayName: $viewModel.displayName)
        case .scaleMode:
            ScaleModeStepView(preferredScaleMode: $viewModel.preferredScaleMode)
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button(action: primaryAction) {
                Text(viewModel.primaryButtonTitle)
                    .frame(maxWidth: .infinity)
            }
            .primaryActionButton()

            if viewModel.step == .profile {
                Button("Skip for now") {
                    viewModel.advance()
                }
                .secondaryActionButton()
            }
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(.thinMaterial)
    }

    private func primaryAction() {
        if viewModel.step.isLast {
            appState.completeOnboarding(
                displayName: viewModel.trimmedDisplayName,
                prefersARMode: viewModel.prefersARMode,
                preferredScaleMode: viewModel.preferredScaleMode
            )
        } else {
            viewModel.advance()
        }
    }
}

private struct WelcomeStepView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.section) {
            PageHeader(
                title: "Welcome to Luna",
                subtitle: "Set up how you want to browse planets, compare scale, and move into AR."
            )

            Card {
                VStack(alignment: .leading, spacing: 14) {
                    IconBadge(systemImage: "moon.stars.fill")

                    Text("Luna keeps AR central, but every core view also works without AR.")
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("You can change these defaults later in Settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct ViewingModeStepView: View {
    @Binding var prefersARMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.section) {
            PageHeader(
                title: "Choose A Starting Mode",
                subtitle: "Pick the experience Luna should prefer when opening space views."
            )

            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Default Viewing Mode")

                CardSection {
                    SelectionRow(
                        title: "AR First",
                        subtitle: "Prioritize placing scaled bodies in your space.",
                        systemImage: "arkit",
                        isSelected: prefersARMode
                    ) {
                        prefersARMode = true
                    }

                    CardDivider(leadingInset: 56)

                    SelectionRow(
                        title: "Visual First",
                        subtitle: "Start with the non-AR visual mode on every platform.",
                        systemImage: "cube.transparent",
                        isSelected: !prefersARMode
                    ) {
                        prefersARMode = false
                    }
                }
            }
        }
    }
}

private struct ProfileStepView: View {
    @Binding var displayName: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.section) {
            PageHeader(
                title: "Personalize Luna",
                subtitle: "Add a display name if you want a lighter, more personal setup."
            )

            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Profile")

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Display Name")
                            .font(.headline)

                        TextField("Optional", text: $displayName)
                            .textFieldStyle(.roundedBorder)
#if os(iOS)
                            .textInputAutocapitalization(.words)
#endif
                    }
                }
            }
        }
    }
}

private struct ScaleModeStepView: View {
    @Binding var preferredScaleMode: ScaleMode

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.section) {
            PageHeader(
                title: "Pick A Scale Default",
                subtitle: "Real solar system distances are huge, so Luna labels compressed modes clearly."
            )

            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Scale Mode")

                CardSection {
                    ForEach(Array(scaleOptions.enumerated()), id: \.element.mode) { index, option in
                        SelectionRow(
                            title: option.mode.title,
                            subtitle: option.subtitle,
                            systemImage: option.systemImage,
                            value: option.value,
                            isSelected: preferredScaleMode == option.mode
                        ) {
                            preferredScaleMode = option.mode
                        }

                        if index < scaleOptions.count - 1 {
                            CardDivider(leadingInset: 56)
                        }
                    }
                }
            }
        }
    }

    private var scaleOptions: [ScaleOption] {
        [
            ScaleOption(
                mode: .educational,
                subtitle: "Keeps planet sizes and distances readable together.",
                systemImage: "graduationcap",
                value: "Recommended"
            ),
            ScaleOption(
                mode: .compressedDistance,
                subtitle: "Brings bodies closer for room-scale comparison.",
                systemImage: "arrow.left.and.right",
                value: "Compressed"
            ),
            ScaleOption(
                mode: .trueDistance,
                subtitle: "Uses accurate distance intent, but it may be impractical in AR.",
                systemImage: "exclamationmark.triangle",
                value: "Huge"
            )
        ]
    }
}

private struct ScaleOption {
    let mode: ScaleMode
    let subtitle: String
    let systemImage: String
    let value: String
}

private struct SelectionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var value: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CardRow {
                HStack(spacing: 12) {
                    RowLabel(
                        title: title,
                        subtitle: subtitle,
                        systemImage: systemImage,
                        value: value
                    )

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
