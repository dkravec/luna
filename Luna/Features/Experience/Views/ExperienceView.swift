import SwiftUI
#if os(iOS)
import ARKit
#endif

struct ExperienceView: View {
    @EnvironmentObject private var appState: LunaAppState
    @State private var isAREnabled = false
    @State private var hasInitializedMode = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.section) {
                PageHeader(
                    title: "AR Experience",
                    subtitle: "Place scaled worlds in your space or browse in visual mode."
                )

                sceneSection

                modeSection

                controlsSection
            }
            .screenContentPadding()
        }
        .appBackground()
        .onAppear {
            appState.loadCelestialBodies()
            initializePreferredModeIfNeeded()
        }
    }

    @ViewBuilder
    private var sceneSection: some View {
        if appState.celestialBodies.isEmpty {
            EmptyStateView(
                title: "No Bodies Loaded",
                systemImage: "sparkles",
                message: "Luna could not load the local celestial body catalog."
            )
        } else {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isAREnabled ? "AR Scene" : "Visual Scene")
                                .font(.headline)

                            Text(sceneSubtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 12)

                        Text(settings.scaleMode == .compressedDistance ? "\(Int(settings.distanceCompression.rounded()))x" : settings.scaleMode.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.06), in: Capsule(style: .continuous))
                    }

#if os(iOS)
                    if isAREnabled, canUseAR {
                        LunaARSceneView(bodies: appState.celestialBodies, settings: settings)
                            .frame(minHeight: 360)
                            .clipShape(RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
                    } else {
                        SolarSystemVisualSceneView(bodies: appState.celestialBodies, settings: settings)
                    }
#else
                    SolarSystemVisualSceneView(bodies: appState.celestialBodies, settings: settings)
#endif
                }
            }
        }
    }

    private var modeSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    IconBadge(systemImage: "viewfinder")

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ready for AR")
                            .font(.headline)

                        Text("Visual mode stays available when AR is off or unsupported.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        setSceneMode(isAR: true)
                    } label: {
                        Label(canUseAR ? "Start AR" : "AR Unavailable", systemImage: "arkit")
                    }
                    .buttonStyle(ActionButtonStyle(emphasis: isAREnabled ? .primary : .secondary))
                    .hapticTap()
                    .disabled(!canUseAR)

                    Button {
                        setSceneMode(isAR: false)
                    } label: {
                        Label("Visual", systemImage: "cube.transparent")
                    }
                    .buttonStyle(ActionButtonStyle(emphasis: isAREnabled ? .secondary : .primary))
                    .hapticTap()
                }
            }
        }
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Scene Controls")

            CardSection {
                NavigationLink {
                    ExperienceScaleModeView(
                        preferredScaleMode: preferredScaleModeBinding,
                        distanceCompression: distanceCompressionBinding
                    )
                    .appBackground()
                } label: {
                    CardRow {
                        RowLabel(
                            title: "Scale Mode",
                            subtitle: scaleModeSubtitle,
                            systemImage: "scale.3d",
                            value: appState.userProfile.preferredScaleMode.title,
                            showsChevron: true
                        )
                    }
                }
                .buttonStyle(.plain)
                .hapticTap()

                CardDivider(leadingInset: 56)

                NavigationLink {
                    ExperiencePlanetSizeView(planetSizeMultiplier: planetSizeMultiplierBinding)
                        .appBackground()
                } label: {
                    CardRow {
                        RowLabel(
                            title: "Planet Size",
                            subtitle: "Scale up small bodies without changing distance labels.",
                            systemImage: "plus.magnifyingglass",
                            value: planetSizeTitle,
                            showsChevron: true
                        )
                    }
                }
                .buttonStyle(.plain)
                .hapticTap()

                CardDivider(leadingInset: 56)

                CardRow {
                    RowLabel(
                        title: "Compressed Distance",
                        subtitle: "Use an educational layout for room-scale viewing.",
                        systemImage: "arrow.up.left.and.arrow.down.right",
                        value: compressedDistanceTitle
                    )
                }

                CardDivider(leadingInset: 56)

                CardRow {
                    Toggle(
                        isOn: Binding(
                            get: { appState.userProfile.showLabels },
                            set: { setShowLabels($0) }
                        )
                    ) {
                        RowLabel(
                            title: "Labels",
                            subtitle: "Show body names in the scene.",
                            systemImage: "tag"
                        )
                    }
                }

                CardDivider(leadingInset: 56)

                CardRow {
                    Toggle(
                        isOn: Binding(
                            get: { appState.userProfile.showOrbits },
                            set: { setShowOrbits($0) }
                        )
                    ) {
                        RowLabel(
                            title: "Orbits",
                            subtitle: "Draw orbit guides when the selected scale mode supports them.",
                            systemImage: "circle.dashed"
                        )
                    }
                }
            }
        }
    }

    private var settings: SolarSystemSceneSettings {
        SolarSystemSceneSettings(
            isAREnabled: isAREnabled,
            scaleMode: appState.userProfile.preferredScaleMode,
            distanceCompression: appState.userProfile.distanceCompression,
            planetSizeMultiplier: appState.userProfile.planetSizeMultiplier,
            showLabels: appState.userProfile.showLabels,
            showOrbits: appState.userProfile.showOrbits
        )
    }

    private var sceneSubtitle: String {
        if isAREnabled {
            return "Place the current solar system scale in your space."
        }

        return "Browse the same scale controls in a non-AR scene."
    }

    private var canUseAR: Bool {
#if os(iOS)
        ARWorldTrackingConfiguration.isSupported
#else
        false
#endif
    }

    private func initializePreferredModeIfNeeded() {
        guard !hasInitializedMode else { return }

        isAREnabled = appState.userProfile.prefersARMode && canUseAR
        hasInitializedMode = true
    }

    private func setSceneMode(isAR: Bool) {
        isAREnabled = isAR && canUseAR
        appState.setPrefersARMode(isAREnabled)
    }

    private func setShowLabels(_ showLabels: Bool) {
        Haptics.selection()
        appState.setShowLabels(showLabels)
    }

    private func setShowOrbits(_ showOrbits: Bool) {
        Haptics.selection()
        appState.setShowOrbits(showOrbits)
    }

    private var preferredScaleModeBinding: Binding<ScaleMode> {
        Binding(
            get: { appState.userProfile.preferredScaleMode },
            set: { appState.setPreferredScaleMode($0) }
        )
    }

    private var distanceCompressionBinding: Binding<Double> {
        Binding(
            get: { appState.userProfile.distanceCompression },
            set: { appState.setDistanceCompression($0) }
        )
    }

    private var planetSizeMultiplierBinding: Binding<Double> {
        Binding(
            get: { appState.userProfile.planetSizeMultiplier },
            set: { appState.setPlanetSizeMultiplier($0) }
        )
    }

    private var scaleModeSubtitle: String {
        switch appState.userProfile.preferredScaleMode {
        case .educational:
            return "Readable sizes and distances together."
        case .compressedDistance:
            return "Distance is compressed for viewing, not accuracy."
        case .trueDistance:
            return "Accurate intent, impractical at room scale."
        case .custom:
            return "Uses your custom scale controls."
        }
    }

    private var planetSizeTitle: String {
        "\(Int(appState.userProfile.planetSizeMultiplier.rounded()))x"
    }

    private var compressedDistanceTitle: String {
        appState.userProfile.preferredScaleMode == .compressedDistance
            ? "\(Int(appState.userProfile.distanceCompression.rounded()))x"
            : "Off"
    }
}

private struct ExperienceScaleModeView: View {
    @Binding var preferredScaleMode: ScaleMode
    @Binding var distanceCompression: Double

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.section) {
                PageHeader(
                    title: "Choose Scaling",
                    subtitle: "Pick how Luna should balance accurate scale with readable space views."
                )

                ScaleModeOptionsView(
                    preferredScaleMode: $preferredScaleMode,
                    distanceCompression: $distanceCompression
                )
            }
            .screenContentPadding()
        }
        .navigationTitle("Scale Mode")
    }
}

private struct ExperiencePlanetSizeView: View {
    @Binding var planetSizeMultiplier: Double

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.section) {
                PageHeader(
                    title: "Planet Size",
                    subtitle: "Choose how large planets appear in AR and visual scenes without changing distance labels."
                )

                PlanetSizeOptionsView(planetSizeMultiplier: $planetSizeMultiplier)
            }
            .screenContentPadding()
        }
        .navigationTitle("Planet Size")
    }
}

struct PlanetSizeOptionsView: View {
    @Binding var planetSizeMultiplier: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Planet Size")

            CardSection {
                ForEach(Array(PlanetSizeMultiplier.allCases.enumerated()), id: \.element.id) { index, option in
                    SelectionRow(
                        title: option.title,
                        subtitle: subtitle(for: option),
                        systemImage: "plus.magnifyingglass",
                        value: value(for: option),
                        isSelected: isSelected(option)
                    ) {
                        planetSizeMultiplier = option.rawValue
                    }

                    if index < PlanetSizeMultiplier.allCases.count - 1 {
                        CardDivider(leadingInset: 56)
                    }
                }
            }
        }
    }

    private func isSelected(_ option: PlanetSizeMultiplier) -> Bool {
        abs(planetSizeMultiplier - option.rawValue) < 0.01
    }

    private func subtitle(for option: PlanetSizeMultiplier) -> String {
        switch option {
        case .one:
            return "Natural display size for the selected scale mode."
        case .two:
            return "A small boost for easier viewing."
        case .five:
            return "Makes smaller worlds easier to see."
        case .ten:
            return "Strong enlargement for room-scale viewing."
        case .twenty:
            return "Maximum enlargement for demos and comparison."
        }
    }

    private func value(for option: PlanetSizeMultiplier) -> String? {
        option == .one ? "Default" : nil
    }
}
