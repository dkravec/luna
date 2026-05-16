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
        .sheet(item: $selectedQuickDetailsBody) { body in
            BodyQuickDetailsView(celestialBody: body)
                .presentationDetents([.medium, .large])
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
        selectedQuickDetailsBody = body
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

struct BodyQuickDetailsView: View {
    let celestialBody: CelestialBody

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.section) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(celestialBody.name)
                            .font(.largeTitle.weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)

                        Text(celestialBody.subtitle)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    CardSection {
                        quickRow(title: "Type", value: celestialBody.type.title, systemImage: "circle.hexagongrid")
                        CardDivider(leadingInset: 56)
                        quickRow(title: "Radius", value: formattedKilometers(celestialBody.radiusKm), systemImage: "ruler")
                        CardDivider(leadingInset: 56)
                        quickRow(title: "Gravity", value: formattedGravity, systemImage: "arrow.down.circle")
                    }

                    CardSection {
                        quickRow(title: "Orbit", value: formattedOrbitPeriod, systemImage: "circle.dashed")
                        CardDivider(leadingInset: 56)
                        quickRow(title: "Rotation", value: formattedRotationPeriod, systemImage: "rotate.3d")
                        CardDivider(leadingInset: 56)
                        quickRow(title: "Rotational Speed", value: formattedRotationalSpeed, systemImage: "speedometer")
                        CardDivider(leadingInset: 56)
                        quickRow(title: "Axial Tilt", value: formattedAxialTilt, systemImage: "gyroscope")
                    }

                    if let orbit = celestialBody.orbit {
                        CardSection {
                            quickRow(title: "Semi-major Axis", value: formattedKilometers(orbit.semiMajorAxisKm), systemImage: "arrow.left.and.right")
                            CardDivider(leadingInset: 56)
                            quickRow(title: "Eccentricity", value: orbit.eccentricity.formatted(.number.precision(.fractionLength(3))), systemImage: "oval")
                            CardDivider(leadingInset: 56)
                            quickRow(title: "Inclination", value: formattedDegrees(orbit.inclinationDegrees), systemImage: "angle")
                        }
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.vertical, 18)
            }
            .appBackground()
            .navigationTitle("Quick Details")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
        }
    }

    private func quickRow(title: String, value: String, systemImage: String) -> some View {
        CardRow {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer(minLength: 12)

                Text(value)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var formattedGravity: String {
        guard let gravity = celestialBody.gravity else { return "Not available" }
        return "\(gravity.formatted(.number.precision(.fractionLength(2)))) m/s^2"
    }

    private var formattedOrbitPeriod: String {
        guard let days = celestialBody.orbitalPeriodDays else { return "Not applicable" }
        if days < 1 {
            return "\(hours(fromDays: days).formatted(.number.precision(.fractionLength(1)))) hours"
        }
        return "\(days.formatted(.number.precision(.fractionLength(1)))) days"
    }

    private var formattedRotationPeriod: String {
        guard let hours = celestialBody.rotationPeriodHours else { return "Not available" }
        let direction = hours < 0 ? " retrograde" : ""
        return "\(abs(hours).formatted(.number.precision(.fractionLength(1)))) hours\(direction)"
    }

    private var formattedRotationalSpeed: String {
        guard let hours = celestialBody.rotationPeriodHours, hours != 0 else { return "Not available" }
        let circumferenceKm = 2 * Double.pi * celestialBody.radiusKm
        let speed = circumferenceKm / abs(hours)
        return "\(speed.formatted(.number.precision(.fractionLength(0)))) km/h"
    }

    private var formattedAxialTilt: String {
        formattedDegrees(celestialBody.axialTiltDegrees ?? Double(ExperienceSceneEngine.axialTiltRadians(for: celestialBody)) * 180 / .pi)
    }

    private func formattedKilometers(_ kilometers: Double) -> String {
        "\(kilometers.formatted(.number.precision(.fractionLength(0)).grouping(.automatic))) km"
    }

    private func formattedDegrees(_ degrees: Double) -> String {
        "\(degrees.formatted(.number.precision(.fractionLength(2)))) deg"
    }

    private func hours(fromDays days: Double) -> Double {
        days * 24
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
