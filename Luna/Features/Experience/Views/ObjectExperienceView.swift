import SwiftUI
#if os(iOS)
import ARKit
#endif

struct ObjectExperienceView: View {
    @EnvironmentObject private var appState: LunaAppState
    @State private var isAREnabled = false
    @State private var hasInitializedMode = false
    @State private var recenterTrigger = 0
    @State private var arPlacementState: ARPlacementState = .initializing
    @State private var selectedQuickDetailsBody: CelestialBody?

    let celestialBody: CelestialBody

    var body: some View {
        ZStack {
#if os(iOS)
            if isAREnabled, canUseAR {
                LunaARSceneView(
                    bodies: bodies,
                    settings: settings,
                    content: .object(celestialBody.id),
                    simulationTimeDays: 0,
                    recenterTrigger: recenterTrigger,
                    onPlacementStateChange: { arPlacementState = $0 },
                    onSelectBody: showQuickDetails(for:)
                )
                .ignoresSafeArea(edges: .bottom)
            } else {
                visualScene
            }
#else
            visualScene
#endif

            VStack {
                topBar
                Spacer()
                placementButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

#if os(iOS)
            arPlacementReticle
#endif

            inSceneQuickDetails
                .padding(.horizontal, 16)
                .padding(.bottom, 84)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .appBackground()
        .navigationTitle("\(celestialBody.name) Experience")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            initializePreferredModeIfNeeded()
        }
#endif
    }

    private var visualScene: some View {
        SolarSystemVisualSceneView(
            bodies: bodies,
            settings: settings,
            content: .object(celestialBody.id),
            simulationTimeDays: 0,
            focusedBodyID: selectedQuickDetailsBody?.id,
            onSelectBody: showQuickDetails(for:)
        )
        .ignoresSafeArea(edges: .bottom)
    }

    private var topBar: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(celestialBody.name)
                    .font(.headline.weight(.semibold))

                Text(isAREnabled ? "AR mode" : "Scene mode")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radii.card, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
            }

            Spacer()

#if os(iOS)
            modeToggle
#endif
        }
    }

#if os(iOS)
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
            .accessibilityLabel("Use scene mode")
        }
        .buttonStyle(.plain)
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var arPlacementReticle: some View {
        if isAREnabled, canUseAR {
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
    }
#endif

    @ViewBuilder
    private var placementButton: some View {
#if os(iOS)
        if isAREnabled, canUseAR {
            Button {
                Haptics.selection()
                recenterTrigger += 1
            } label: {
                Label(arPlacementTitle, systemImage: "scope")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(height: 52)
                    .background(Color.accentColor, in: Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!arPlacementState.isReady)
            .opacity(arPlacementState.isReady ? 1 : 0.62)
        }
#endif
    }

    private var arPlacementTitle: String {
        arPlacementState.isReady ? (recenterTrigger == 0 ? "Place" : "Re-place") : arPlacementState.title
    }

    private var arPlacementColor: Color {
        arPlacementState.isReady ? Color.accentColor : .white
    }

    @ViewBuilder
    private var inSceneQuickDetails: some View {
        if let selectedQuickDetailsBody {
            InSceneBodyQuickDetailsCard(
                celestialBody: selectedQuickDetailsBody,
                childBodies: childBodies(for: selectedQuickDetailsBody),
                allBodies: bodies
            ) {
                Haptics.selection()
                self.selectedQuickDetailsBody = nil
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
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

    private var bodies: [CelestialBody] {
        appState.celestialBodies.isEmpty ? [celestialBody] : appState.celestialBodies
    }

    private var settings: ExperienceSceneSettings {
        ExperienceSceneSettings(
            isAREnabled: isAREnabled,
            preferences: appState.experiencePreferences,
            sceneScaleProfileOverride: .uniform
        )
    }

#if os(iOS)
    private func initializePreferredModeIfNeeded() {
        guard !hasInitializedMode else { return }

        isAREnabled = canUseAR && appState.experiencePreferences.prefersARMode
        hasInitializedMode = true
    }

    private func setSceneMode(isAR: Bool) {
        Haptics.selection()
        isAREnabled = isAR && canUseAR
        appState.setPrefersARMode(isAREnabled)
        if !isAREnabled {
            recenterTrigger = 0
            arPlacementState = .initializing
        }
    }
#endif

    private var canUseAR: Bool {
#if os(iOS)
        ARWorldTrackingConfiguration.isSupported
#else
        false
#endif
    }
}
