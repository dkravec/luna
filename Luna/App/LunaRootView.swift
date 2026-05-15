import SwiftUI

struct LunaRootView: View {
    @EnvironmentObject private var appState: LunaAppState

    var body: some View {
        if appState.userProfile.hasCompletedOnboarding {
            LunaAdaptiveShell()
        } else {
            OnboardingFlowView()
        }
    }
}
