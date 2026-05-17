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
                    Haptics.selection()
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
        case .profile:
            ProfileStepView(displayName: $viewModel.displayName)
        case .viewingMode:
            ViewingModeStepView(prefersARMode: $viewModel.prefersARMode)
        case .scaleMode:
            ScaleModeStepView(
                distanceScaleMode: $viewModel.distanceScaleMode,
                objectScaleMode: $viewModel.objectScaleMode,
                distanceCompression: $viewModel.distanceCompression
            )
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
                distanceScaleMode: viewModel.distanceScaleMode,
                objectScaleMode: viewModel.objectScaleMode,
                distanceCompression: viewModel.distanceCompression
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
                subtitle: "Explore planets, compare scale, and place worlds around you with AR."
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

            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "What Luna Does")

                CardSection {
                    OnboardingFeatureRow(
                        title: "Browse Nearby Worlds",
                        subtitle: "Start with the Sun, planets, and the Moon from local data.",
                        systemImage: "circle.grid.cross"
                    )

                    CardDivider(leadingInset: 56)

                    OnboardingFeatureRow(
                        title: "Compare Scale",
                        subtitle: "Switch between educational, compressed, and true-distance views.",
                        systemImage: "scale.3d"
                    )

                    CardDivider(leadingInset: 56)

                    OnboardingFeatureRow(
                        title: "Use AR When It Fits",
                        subtitle: "Place planets in your space, with visual mode always available.",
                        systemImage: "arkit"
                    )
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
                title: "Choose View Mode",
                subtitle: "Pick the experience Luna should prefer when opening space views."
            )

            ViewingModeOptionsView(prefersARMode: $prefersARMode)
        }
    }
}

private struct ProfileStepView: View {
    @Binding var displayName: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.section) {
            PageHeader(
                title: "Personalize Luna",
                subtitle: "Add an optional display name for your profile."
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
    @Binding var distanceScaleMode: DistanceScaleMode
    @Binding var objectScaleMode: ObjectScaleMode
    @Binding var distanceCompression: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.section) {
            PageHeader(
                title: "Choose Scaling",
                subtitle: "Pick how Luna should balance accurate scale with readable space views."
            )

            DistanceScaleOptionsView(
                distanceScaleMode: $distanceScaleMode,
                distanceCompression: $distanceCompression
            )

            ObjectScaleOptionsView(objectScaleMode: $objectScaleMode)
        }
    }
}

struct ViewingModeOptionsView: View {
    @Binding var prefersARMode: Bool

    var body: some View {
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

struct DistanceScaleOptionsView: View {
    @Binding var distanceScaleMode: DistanceScaleMode
    var distanceCompression: Binding<Double>? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.section) {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Distance Scale")

                CardSection {
                    ForEach(Array(scaleOptions.enumerated()), id: \.element.mode) { index, option in
                        SelectionRow(
                            title: option.mode.title,
                            subtitle: option.subtitle,
                            systemImage: option.systemImage,
                            value: option.value,
                            isSelected: distanceScaleMode == option.mode
                        ) {
                            distanceScaleMode = option.mode
                        }

                        if index < scaleOptions.count - 1 {
                            CardDivider(leadingInset: 56)
                        }
                    }
                }
            }

            if distanceScaleMode == .compressed, let distanceCompression {
                compressionSection(distanceCompression)
            }
        }
    }

    private func compressionSection(_ distanceCompression: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Compression")

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    RowLabel(
                        title: "Distance Compression",
                        subtitle: "Brings faraway bodies closer for viewing. This is a viewing aid, not accurate distance.",
                        systemImage: "arrow.left.and.right",
                        value: "\(Int(distanceCompression.wrappedValue.rounded()))x"
                    )

                    Slider(
                        value: distanceCompression,
                        in: 5...100,
                        step: 5
                    ) {
                        Text("Distance Compression")
                    } minimumValueLabel: {
                        Text("5x")
                    } maximumValueLabel: {
                        Text("100x")
                    }
                }
            }
        }
    }

    private var scaleOptions: [ScaleOption] {
        [
            ScaleOption(
                mode: .educational,
                subtitle: "Keeps distances equally spaced and readable.",
                systemImage: "graduationcap",
                value: "Recommended"
            ),
            ScaleOption(
                mode: .compressed,
                subtitle: "Preserves distance order while pulling worlds closer.",
                systemImage: "arrow.left.and.right",
                value: "Compressed"
            ),
            ScaleOption(
                mode: .trueScale,
                subtitle: "Uses real distance ratios; objects may be very far apart.",
                systemImage: "exclamationmark.triangle",
                value: "Huge"
            )
        ]
    }
}

struct ScaleOption {
    let mode: DistanceScaleMode
    let subtitle: String
    let systemImage: String
    let value: String
}

struct ObjectScaleOptionsView: View {
    @Binding var objectScaleMode: ObjectScaleMode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Object Scale")

            CardSection {
                ForEach(Array(ObjectScaleMode.allCases.enumerated()), id: \.element.id) { index, mode in
                    SelectionRow(
                        title: mode.title,
                        subtitle: mode.subtitle,
                        systemImage: systemImage(for: mode),
                        value: mode == .relative ? "Recommended" : nil,
                        isSelected: objectScaleMode == mode
                    ) {
                        objectScaleMode = mode
                    }

                    if index < ObjectScaleMode.allCases.count - 1 {
                        CardDivider(leadingInset: 56)
                    }
                }
            }
        }
    }

    private func systemImage(for mode: ObjectScaleMode) -> String {
        switch mode {
        case .uniform:
            return "circle.grid.2x2"
        case .relative:
            return "scale.3d"
        case .trueScale:
            return "ruler"
        }
    }
}

struct SelectionRow: View {
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
        .hapticTap()
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct OnboardingFeatureRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        CardRow {
            RowLabel(
                title: title,
                subtitle: subtitle,
                systemImage: systemImage
            )
        }
    }
}
