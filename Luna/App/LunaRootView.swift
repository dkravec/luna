import SwiftUI

struct LunaRootView: View {
    @EnvironmentObject private var appState: LunaAppState

    var body: some View {
        Group {
            if appState.userProfile.hasCompletedOnboarding {
                LunaAdaptiveShell()
            } else {
                OnboardingFlowView()
            }
        }
        .id(appState.userProfile.hasCompletedOnboarding)
    }
}
