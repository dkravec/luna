import Combine
import SwiftUI
#if os(iOS)
import ARKit
#endif

struct ExperienceView: View {
    private static let playbackTimer = Timer
        .publish(every: 1.0 / 24.0, on: .main, in: .common)
        .autoconnect()

    @EnvironmentObject private var appState: LunaAppState
    @Environment(\.lunaCustomTabBarReserveIsActive) private var hasCustomTabBarReserve
    @State private var isAREnabled = false
    @State private var hasInitializedMode = false
    @State private var isControlsPresented = false
    @State private var isSceneReady = false
    @State private var recenterTrigger = 0
    @State private var isOrbitPlaybackEnabled = false
    @State private var playbackStartDate = Date()
    @State private var pausedSimulationDays: Double = 0
    @State private var currentSimulationDays: Double = 0
    @State private var arPlacementState: ARPlacementState = .initializing
    @State private var showsARDebugSurfaces = false
    @State private var selectedQuickDetailsBody: CelestialBody?

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

            inSceneQuickDetails
                .padding(.horizontal, 16)
                .padding(.bottom, quickDetailsBottomPadding)
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
        .onDisappear {
            pauseOrbitPlaybackIfNeeded()
        }
        .onChange(of: appState.selectedTab) { selectedTab in
            if selectedTab != .arExperience {
                pauseOrbitPlaybackIfNeeded()
            }
        }
        .onReceive(Self.playbackTimer) { date in
            advanceOrbitPlaybackIfNeeded(at: date)
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
            sceneContent(simulationTimeDays: currentSimulationDays)
        }
    }

    @ViewBuilder
    private func sceneContent(simulationTimeDays: Double) -> some View {
#if os(iOS)
        if isAREnabled, canUseAR {
            LunaARSceneView(
                bodies: appState.celestialBodies,
                settings: settings,
                content: .solarSystem,
                simulationTimeDays: simulationTimeDays,
                recenterTrigger: recenterTrigger,
                showsDebugSurfaces: showsARDebugSurfaces,
                onPlacementStateChange: { arPlacementState = $0 },
                onSelectBody: showQuickDetails(for:)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            SolarSystemVisualSceneView(
                bodies: appState.celestialBodies,
                settings: settings,
                content: .solarSystem,
                simulationTimeDays: simulationTimeDays,
                focusedBodyID: selectedQuickDetailsBody?.id,
                onSelectBody: showQuickDetails(for:)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
#else
        SolarSystemVisualSceneView(
            bodies: appState.celestialBodies,
            settings: settings,
            content: .solarSystem,
            simulationTimeDays: simulationTimeDays,
            focusedBodyID: selectedQuickDetailsBody?.id,
            onSelectBody: showQuickDetails(for:)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
#endif
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

                Button {
                    toggleOrbitPlayback()
                } label: {
                    Image(systemName: isOrbitPlaybackEnabled ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 46, height: 46)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isOrbitPlaybackEnabled ? "Pause orbits" : "Play orbits")
            }
        }
    }

    @ViewBuilder
    private var arPlacementReticle: some View {
#if os(iOS)
        if isSceneReady, isAREnabled, canUseAR, !appState.celestialBodies.isEmpty {
            ZStack {
                Circle()
                    .stroke(arPlacementColor.opacity(0.88), lineWidth: 2)
                    .frame(width: 58, height: 58)

                Circle()
                    .stroke(arPlacementColor.opacity(0.26), lineWidth: 10)
                    .frame(width: 58, height: 58)

                Circle()
                    .fill(arPlacementColor.opacity(0.88))
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
            .disabled(!arPlacementState.isReady)
            .opacity(arPlacementState.isReady ? 1 : 0.62)
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
                    DistanceScaleOptionsView(
                        distanceScaleMode: distanceScaleModeBinding,
                        distanceCompression: distanceCompressionBinding
                    )
                    ObjectScaleOptionsView(objectScaleMode: objectScaleModeBinding)
                    orbitPlaybackSection
                    objectRotationSection
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
                            get: { appState.experiencePreferences.showLabels },
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
                            get: { appState.experiencePreferences.showOrbits },
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

#if os(iOS)
                if isAREnabled, canUseAR {
                    CardDivider(leadingInset: 56)

                    CardRow {
                        Toggle(isOn: $showsARDebugSurfaces) {
                            RowLabel(
                                title: "AR Surface Debug",
                                subtitle: "Show detected planes, anchor origins, and feature points.",
                                systemImage: "viewfinder"
                            )
                        }
                    }
                }
#endif
            }
        }
    }

    private var orbitPlaybackSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Orbit Playback")

            CardSection {
                ForEach(Array(OrbitPlaybackSpeed.allCases.enumerated()), id: \.element.id) { index, speed in
                    SelectionRow(
                        title: speed.title,
                        subtitle: "\(Int(speed.daysPerSecond)) simulated days per second.",
                        systemImage: "play.circle",
                        value: speed == .standard ? "Default" : nil,
                        isSelected: appState.experiencePreferences.orbitPlaybackSpeed == speed
                    ) {
                        appState.setOrbitPlaybackSpeed(speed)
                    }

                    if index < OrbitPlaybackSpeed.allCases.count - 1 {
                        CardDivider(leadingInset: 56)
                    }
                }
            }
        }
    }

    private var objectRotationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Object Rotation")

            CardSection {
                ForEach(Array(ObjectRotationSpeed.allCases.enumerated()), id: \.element.id) { index, speed in
                    SelectionRow(
                        title: speed.title,
                        subtitle: speed == .off ? "Keep objects still while orbit playback runs." : "Controls visible object spin during playback.",
                        systemImage: "rotate.3d",
                        value: speed == .slow ? "Default" : nil,
                        isSelected: appState.experiencePreferences.objectRotationSpeed == speed
                    ) {
                        Haptics.selection()
                        appState.setObjectRotationSpeed(speed)
                    }

                    if index < ObjectRotationSpeed.allCases.count - 1 {
                        CardDivider(leadingInset: 56)
                    }
                }
            }
        }
    }

    private var settings: ExperienceSceneSettings {
        ExperienceSceneSettings(
            isAREnabled: isAREnabled,
            preferences: appState.experiencePreferences
        )
    }

    private var sceneSubtitle: String {
        if isAREnabled {
            return arPlacementState.isReady
                ? (recenterTrigger == 0 ? "Line up the target, then place Luna on the surface." : "Re-place Luna flat on the detected surface.")
                : arPlacementState.message
        }

        return "Browse the same scale controls in a non-AR scene."
    }

    private var arPlacementTitle: String {
        arPlacementState.isReady ? (recenterTrigger == 0 ? "Place" : "Re-place") : arPlacementState.title
    }

    private var arPlacementAccessibilityLabel: String {
        arPlacementState.isReady
            ? (recenterTrigger == 0 ? "Place AR scene" : "Re-place AR scene")
            : arPlacementState.message
    }

    private var arPlacementColor: Color {
        arPlacementState.isReady ? Color.accentColor : .white
    }

    private var arPlacementBottomPadding: CGFloat {
        (hasCustomTabBarReserve ? Spacing.customTabBarBottomReserve : 0) + 26
    }

    private var quickDetailsBottomPadding: CGFloat {
        (hasCustomTabBarReserve ? Spacing.customTabBarBottomReserve : 0) + 92
    }

    @ViewBuilder
    private var inSceneQuickDetails: some View {
        if let selectedQuickDetailsBody {
            InSceneBodyQuickDetailsCard(
                celestialBody: selectedQuickDetailsBody,
                childBodies: childBodies(for: selectedQuickDetailsBody)
            ) {
                Haptics.selection()
                self.selectedQuickDetailsBody = nil
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
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

        isAREnabled = appState.experiencePreferences.prefersARMode && canUseAR
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

    private func toggleOrbitPlayback() {
        Haptics.selection()
        if isOrbitPlaybackEnabled {
            pauseOrbitPlaybackIfNeeded()
        } else {
            pausedSimulationDays = currentSimulationDays
            playbackStartDate = Date()
            isOrbitPlaybackEnabled = true
        }
    }

    private func pauseOrbitPlaybackIfNeeded() {
        guard isOrbitPlaybackEnabled else { return }

        currentSimulationDays = simulationTimeDays(at: Date())
        pausedSimulationDays = currentSimulationDays
        isOrbitPlaybackEnabled = false
    }

    private func advanceOrbitPlaybackIfNeeded(at date: Date) {
        guard isOrbitPlaybackEnabled else { return }

        currentSimulationDays = simulationTimeDays(at: date)
    }

    private func simulationTimeDays(at date: Date) -> Double {
        guard isOrbitPlaybackEnabled else { return pausedSimulationDays }
        return pausedSimulationDays + date.timeIntervalSince(playbackStartDate) * appState.experiencePreferences.orbitPlaybackSpeed.daysPerSecond
    }

    private func placeARScene() {
        Haptics.selection()
        recenterTrigger += 1
    }

    private func showQuickDetails(for body: CelestialBody) {
        Haptics.selection()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            selectedQuickDetailsBody = body
        }
    }

    private func childBodies(for body: CelestialBody) -> [CelestialBody] {
        appState.celestialBodies
            .filter { $0.parentBodyId == body.id }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    private func setShowLabels(_ showLabels: Bool) {
        Haptics.selection()
        appState.setShowLabels(showLabels)
    }

    private func setShowOrbits(_ showOrbits: Bool) {
        Haptics.selection()
        appState.setShowOrbits(showOrbits)
    }

    private var distanceScaleModeBinding: Binding<DistanceScaleMode> {
        Binding(
            get: { appState.experiencePreferences.distanceScaleMode },
            set: { appState.setDistanceScaleMode($0) }
        )
    }

    private var distanceCompressionBinding: Binding<Double> {
        Binding(
            get: { appState.experiencePreferences.distanceCompression },
            set: { appState.setDistanceCompression($0) }
        )
    }

    private var objectScaleModeBinding: Binding<ObjectScaleMode> {
        Binding(
            get: { appState.experiencePreferences.objectScaleMode },
            set: { appState.setObjectScaleMode($0) }
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

struct InSceneBodyQuickDetailsCard: View {
    let celestialBody: CelestialBody
    let childBodies: [CelestialBody]
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(celestialBody.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)

                    Text(celestialBody.type.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.70))
                }

                Spacer(minLength: 8)

                NavigationLink {
                    BodyDetailView(celestialBody: celestialBody, childBodies: childBodies)
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title3.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .foregroundStyle(.white)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .frame(width: 36, height: 36)
                        .foregroundStyle(.white.opacity(0.86))
                        .background(.white.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                compactFact(title: "Orbit", value: orbitValue, systemImage: "circle.dashed")
                compactFact(title: "Rotation", value: rotationValue, systemImage: "rotate.3d")
                compactFact(title: "Speed", value: rotationalSpeedValue, systemImage: "speedometer")
            }
        }
        .padding(14)
        .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radii.card, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 10)
    }

    private func compactFact(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.62))

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: Radii.tile, style: .continuous))
    }

    private var orbitValue: String {
        guard let days = celestialBody.orbitalPeriodDays else { return "N/A" }
        if days >= 365 {
            return "\(format(days / 365.25)) yr"
        }
        if days < 1 {
            return "\(format(days * 24)) hr"
        }
        return "\(format(days)) d"
    }

    private var rotationValue: String {
        guard let hours = celestialBody.rotationPeriodHours else { return "N/A" }
        return "\(format(abs(hours))) hr"
    }

    private var rotationalSpeedValue: String {
        guard let hours = celestialBody.rotationPeriodHours, hours != 0 else { return "N/A" }
        let speed = 2 * Double.pi * celestialBody.radiusKm / abs(hours)
        if speed >= 1_000 {
            return "\(format(speed / 1_000))k km/h"
        }
        return "\(format(speed)) km/h"
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(value >= 100 ? 0 : 1)))
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
