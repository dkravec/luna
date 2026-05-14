import SwiftUI

struct ARExperienceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("AR Experience")
                    .font(.largeTitle.weight(.bold))

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("AR First, Browse Anywhere", systemImage: "arkit")
                            .font(.headline)
                        Text("The AR renderer will be isolated here. iOS will use ARKit and RealityKit when supported; macOS will keep a non-AR visual mode.")
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
