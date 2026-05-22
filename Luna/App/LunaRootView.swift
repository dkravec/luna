import SwiftUI
#if os(iOS)
import ARKit
#endif

struct LunaRootView: View {
    @EnvironmentObject private var appState: LunaAppState

    var body: some View {
        Group {
            if ScreenshotMode.isEnabled, appState.userProfile.hasCompletedOnboarding {
                ScreenshotRootView()
            } else if appState.userProfile.hasCompletedOnboarding {
                LunaAdaptiveShell()
            } else {
                OnboardingFlowView()
            }
        }
        .id(appState.userProfile.hasCompletedOnboarding)
    }
}

private struct ScreenshotRootView: View {
    @EnvironmentObject private var appState: LunaAppState

    var body: some View {
        switch ScreenshotMode.screen {
        case .objectDetail:
            NavigationStack {
                if let body = screenshotBody {
                    BodyDetailView(
                        celestialBody: body,
                        childBodies: childBodies(for: body),
                        allBodies: appState.celestialBodies
                    )
                } else {
                    LunaAdaptiveShell()
                }
            }
        case .apod:
            NavigationStack {
                NASAImageOfTheDayDetailView(
                    item: ScreenshotMode.demoAPOD,
                    showsHistory: false
                )
            }
        case .scaleControls:
            NavigationStack {
                ScreenshotScaleControlsView()
            }
        case .home, .exploreLibrary, .sceneExperience, .arPlacement, .macMainWindow, .none:
            LunaAdaptiveShell()
        }
    }

    private var screenshotBody: CelestialBody? {
        appState.celestialBodies.first { $0.id == "earth" }
            ?? appState.celestialBodies.first { $0.type == .planet }
    }

    private func childBodies(for body: CelestialBody) -> [CelestialBody] {
        appState.celestialBodies
            .filter { $0.parentBodyId == body.id }
            .sorted { $0.displayOrder < $1.displayOrder }
    }
}

private struct ScreenshotScaleControlsView: View {
    @EnvironmentObject private var appState: LunaAppState

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.section) {
                PageHeader(
                    title: "Scale Controls",
                    subtitle: "Compare true scale or readable scale."
                )

                ExperienceCustomizationView(
                    canUseAR: canUseAR,
                    preferredARMode: preferredARModeBinding,
                    sceneScaleProfile: sceneScaleProfileBinding,
                    distanceScaleMode: distanceScaleModeBinding,
                    objectScaleMode: objectScaleModeBinding,
                    distanceCompression: distanceCompressionBinding,
                    renderDetail: renderDetailBinding,
                    showLabels: showLabelsBinding,
                    showOrbits: showOrbitsBinding
                )
            }
            .screenContentPadding()
        }
        .appBackground()
        .navigationTitle("Scale Controls")
    }

    private var canUseAR: Bool {
#if os(iOS)
        ARWorldTrackingConfiguration.isSupported
#else
        false
#endif
    }

    private var preferredARModeBinding: Binding<Bool> {
        Binding(
            get: { appState.experiencePreferences.prefersARMode },
            set: { appState.setPrefersARMode($0) }
        )
    }

    private var sceneScaleProfileBinding: Binding<SceneScaleProfile> {
        Binding(
            get: { appState.experiencePreferences.sceneScaleProfile },
            set: { appState.setSceneScaleProfile($0) }
        )
    }

    private var distanceScaleModeBinding: Binding<DistanceScaleMode> {
        Binding(
            get: { appState.experiencePreferences.distanceScaleMode },
            set: { appState.setDistanceScaleMode($0) }
        )
    }

    private var objectScaleModeBinding: Binding<ObjectScaleMode> {
        Binding(
            get: { appState.experiencePreferences.objectScaleMode },
            set: { appState.setObjectScaleMode($0) }
        )
    }

    private var distanceCompressionBinding: Binding<Double> {
        Binding(
            get: { appState.experiencePreferences.distanceCompression },
            set: { appState.setDistanceCompression($0) }
        )
    }

    private var renderDetailBinding: Binding<SceneRenderDetail> {
        Binding(
            get: { appState.experiencePreferences.renderDetail },
            set: { appState.setRenderDetail($0) }
        )
    }

    private var showLabelsBinding: Binding<Bool> {
        Binding(
            get: { appState.experiencePreferences.showLabels },
            set: { appState.setShowLabels($0) }
        )
    }

    private var showOrbitsBinding: Binding<Bool> {
        Binding(
            get: { appState.experiencePreferences.showOrbits },
            set: { appState.setShowOrbits($0) }
        )
    }
}
