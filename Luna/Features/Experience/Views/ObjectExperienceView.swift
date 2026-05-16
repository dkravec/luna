import SwiftUI
#if os(iOS)
import ARKit
#endif

struct ObjectExperienceView: View {
    @EnvironmentObject private var appState: LunaAppState
    @State private var isAREnabled = false
    @State private var recenterTrigger = 0

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
                    recenterTrigger: recenterTrigger
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
        }
        .appBackground()
        .navigationTitle("\(celestialBody.name) Experience")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isAREnabled = canUseAR && appState.experiencePreferences.prefersARMode
        }
#endif
    }

    private var visualScene: some View {
        SolarSystemVisualSceneView(
            bodies: bodies,
            settings: settings,
            content: .object(celestialBody.id),
            simulationTimeDays: 0
        )
        .ignoresSafeArea(edges: .bottom)
    }

    private var topBar: some View {
        HStack {
            Text(celestialBody.name)
                .font(.headline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(.ultraThinMaterial, in: Capsule(style: .continuous))

            Spacer()

#if os(iOS)
            if canUseAR {
                Button {
                    Haptics.selection()
                    isAREnabled.toggle()
                } label: {
                    Image(systemName: isAREnabled ? "arkit" : "cube.transparent")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
            }
#endif
        }
    }

    @ViewBuilder
    private var placementButton: some View {
#if os(iOS)
        if isAREnabled, canUseAR {
            Button {
                Haptics.selection()
                recenterTrigger += 1
            } label: {
                Label(recenterTrigger == 0 ? "Place" : "Re-place", systemImage: "scope")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(height: 52)
                    .background(Color.accentColor, in: Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
        }
#endif
    }

    private var bodies: [CelestialBody] {
        appState.celestialBodies.isEmpty ? [celestialBody] : appState.celestialBodies
    }

    private var settings: ExperienceSceneSettings {
        ExperienceSceneSettings(isAREnabled: isAREnabled, preferences: appState.experiencePreferences)
    }

    private var canUseAR: Bool {
#if os(iOS)
        ARWorldTrackingConfiguration.isSupported
#else
        false
#endif
    }
}
