import SwiftUI

struct HomeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Luna")
                    .font(.largeTitle.weight(.bold))

                Text("Explore the Solar System, compare scale, and prepare for AR planet viewing.")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Phase 1 Shell", systemImage: "sparkles")
                            .font(.headline)
                        Text("The clean SwiftUI foundation is in place. Data, onboarding, browser details, and AR rendering arrive in later phases.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .screenContentPadding()
        }
        .appBackground()
    }
}
