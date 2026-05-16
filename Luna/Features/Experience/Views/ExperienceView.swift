import SwiftUI
#if os(iOS)
import ARKit
#endif

struct ExperienceView: View {
    @EnvironmentObject private var appState: LunaAppState
    @Environment(\.lunaCustomTabBarReserveIsActive) private var hasCustomTabBarReserve
    @State private var isAREnabled = false
    @State private var hasInitializedMode = false
    @State private var isControlsPresented = false
    @State private var isSceneReady = false
    @State private var recenterTrigger = 0

    var body: some View {
        ZStack {
            sceneLayer
                .ignoresSafeArea(edges: .bottom)

            topBar
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            arPlacementReticle

            arPlacementButton
                .padding(.bottom, arPlacementBottomPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .appBackground()
        .onAppear {
            if appState.celestialBodies.isEmpty {
                appState.loadCelestialBodies()
            }
            initializePreferredModeIfNeeded()
            prepareSceneAfterInitialRender()
        }
        .sheet(isPresented: $isControlsPresented) {
            controlsSheetContent
                .experienceControlsPresentation()
        }
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
#endif
    }

    @ViewBuilder
    private var sceneLayer: some View {
        if !isSceneReady {
            ExperienceLoadingView()
        } else if appState.celestialBodies.isEmpty {
            EmptyStateView(
                title: "No Bodies Loaded",
                systemImage: "sparkles",
                message: "Luna could not load the local celestial body catalog."
            )
            .padding()
        } else {
#if os(iOS)
            if isAREnabled, canUseAR {
                LunaARSceneView(
                    bodies: appState.celestialBodies,
                    settings: settings,
                    recenterTrigger: recenterTrigger
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                SolarSystemVisualSceneView(bodies: appState.celestialBodies, settings: settings)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
#else
            SolarSystemVisualSceneView(bodies: appState.celestialBodies, settings: settings)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
#endif
        }
    }

    private var topBar: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Experience")
                    .font(.largeTitle.weight(.bold))

                Text(sceneSubtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radii.card, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
            }

            Spacer(minLength: 8)

            VStack(spacing: 10) {
                modeToggle

                Button {
                    Haptics.selection()
                    isControlsPresented = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 46, height: 46)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show experience controls")
            }
        }
    }

    @ViewBuilder
    private var arPlacementReticle: some View {
#if os(iOS)
        if isSceneReady, isAREnabled, canUseAR, !appState.celestialBodies.isEmpty {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.88), lineWidth: 2)
                    .frame(width: 58, height: 58)

                Circle()
                    .stroke(.white.opacity(0.26), lineWidth: 10)
                    .frame(width: 58, height: 58)

                Circle()
                    .fill(Color.accentColor.opacity(0.88))
                    .frame(width: 8, height: 8)
            }
            .shadow(color: .black.opacity(0.42), radius: 12, x: 0, y: 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
#endif
    }

    @ViewBuilder
    private var arPlacementButton: some View {
#if os(iOS)
        if isSceneReady, isAREnabled, canUseAR, !appState.celestialBodies.isEmpty {
            Button {
                placeARScene()
            } label: {
                Label(arPlacementTitle, systemImage: "scope")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(height: 52)
                    .background(Color.accentColor, in: Capsule(style: .continuous))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(.white.opacity(0.22), lineWidth: 1)
                    }
                    .shadow(color: Color.accentColor.opacity(0.38), radius: 18, x: 0, y: 8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(arPlacementAccessibilityLabel)
        }
#endif
    }

    private var modeToggle: some View {
        HStack(spacing: 4) {
            Button {
                setSceneMode(isAR: true)
            } label: {
                Image(systemName: "arkit")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background {
                        if isAREnabled {
                            Circle().fill(Color.accentColor.opacity(0.18))
                        }
                    }
            }
            .disabled(!canUseAR)
            .foregroundStyle(isAREnabled ? Color.accentColor : Color.secondary)
            .accessibilityLabel(canUseAR ? "Use AR mode" : "AR unavailable")

            Button {
                setSceneMode(isAR: false)
            } label: {
                Image(systemName: "cube.transparent")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background {
                        if !isAREnabled {
                            Circle().fill(Color.accentColor.opacity(0.18))
                        }
                    }
            }
            .foregroundStyle(!isAREnabled ? Color.accentColor : Color.secondary)
            .accessibilityLabel("Use visual mode")
        }
        .buttonStyle(.plain)
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        }
    }

    private var controlsSheetContent: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.section) {
                    viewModeSection
                    ScaleModeOptionsView(
                        preferredScaleMode: preferredScaleModeBinding,
                        distanceCompression: distanceCompressionBinding
                    )
                    PlanetSizeOptionsView(planetSizeMultiplier: planetSizeMultiplierBinding)
                    sceneOptionsSection
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .appBackground()
            .navigationTitle("Experience")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isControlsPresented = false
                    }
                }
            }
        }
    }

    private var viewModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "View Mode")

            CardSection {
                SelectionRow(
                    title: "AR",
                    subtitle: canUseAR ? "Place scaled bodies in your space." : "AR is not available on this device.",
                    systemImage: "arkit",
                    value: canUseAR ? nil : "Unavailable",
                    isSelected: isAREnabled
                ) {
                    setSceneMode(isAR: true)
                }
                .disabled(!canUseAR)

                CardDivider(leadingInset: 56)

                SelectionRow(
                    title: "Visual",
                    subtitle: "Use the same scene controls without AR.",
                    systemImage: "cube.transparent",
                    isSelected: !isAREnabled
                ) {
                    setSceneMode(isAR: false)
                }
            }
        }
    }

    private var sceneOptionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Scene")

            CardSection {
                CardRow {
                    Toggle(
                        isOn: Binding(
                            get: { appState.userProfile.showLabels },
                            set: { setShowLabels($0) }
                        )
                    ) {
                        RowLabel(
                            title: "Labels",
                            subtitle: "Show body names in visual scenes.",
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
                            title: "Orbit Guides",
                            subtitle: "Show subtle distance guides in visual mode.",
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
            return recenterTrigger == 0
                ? "Line up the target, then place Luna in your space."
                : "Re-place Luna whenever you want a cleaner anchor."
        }

        return "Browse the same scale controls in a non-AR scene."
    }

    private var arPlacementTitle: String {
        recenterTrigger == 0 ? "Place" : "Re-place"
    }

    private var arPlacementAccessibilityLabel: String {
        recenterTrigger == 0 ? "Place AR scene" : "Re-place AR scene"
    }

    private var arPlacementBottomPadding: CGFloat {
        (hasCustomTabBarReserve ? Spacing.customTabBarBottomReserve : 0) + 26
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

    private func prepareSceneAfterInitialRender() {
        guard !isSceneReady else { return }

        Task {
            try? await Task.sleep(nanoseconds: 140_000_000)

            await MainActor.run {
                isSceneReady = true
            }
        }
    }

    private func setSceneMode(isAR: Bool) {
        isAREnabled = isAR && canUseAR
        appState.setPrefersARMode(isAREnabled)
    }

    private func placeARScene() {
        Haptics.selection()
        recenterTrigger += 1
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
}

private struct ExperienceLoadingView: View {
    var body: some View {
        ZStack {
            Color.clear

            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)

                Text("Preparing Experience")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.86))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radii.card, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func experienceControlsPresentation() -> some View {
#if os(iOS)
        self
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
#else
        self
            .frame(minWidth: 390, minHeight: 560)
#endif
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
            return "Closer to the real relative sizes of the planets."
        case .two:
            return "A small readability boost with restrained scale."
        case .five:
            return "Default readable scale for AR and visual mode."
        case .ten:
            return "Strong enlargement for room-scale viewing."
        case .twenty:
            return "Maximum enlargement for demos and comparison."
        }
    }

    private func value(for option: PlanetSizeMultiplier) -> String? {
        option == .five ? "Default" : nil
    }
}
