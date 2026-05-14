import SwiftUI

struct SolarSystemView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Solar System")
                    .font(.largeTitle.weight(.bold))

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Planet Browser", systemImage: "sun.max")
                            .font(.headline)
                        Text("This view will load bodies from local JSON and support scale controls in Phase 5.")
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
