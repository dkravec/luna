import SwiftUI

struct SolarSystemView: View {
    @EnvironmentObject private var appState: LunaAppState

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.section) {
                PageHeader(
                    title: "Solar System",
                    subtitle: "Browse nearby worlds with readable scale controls."
                )

                scaleSection

                previewSection
            }
            .screenContentPadding()
        }
        .appBackground()
    }

    private var scaleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Scale")

            CardSection {
                CardRow {
                    RowLabel(
                        title: "Educational",
                        subtitle: "Keeps planets and distances readable together.",
                        systemImage: "graduationcap",
                        value: appState.userProfile.preferredScaleMode.title
                    )
                }

                CardDivider(leadingInset: 56)

                CardRow {
                    RowLabel(
                        title: "Distance Compression",
                        subtitle: "Brings faraway bodies closer for comparison.",
                        systemImage: "arrow.left.and.right",
                        value: "Clearly labeled"
                    )
                }
            }
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Bodies")

            CardSection {
                CardRow {
                    RowLabel(
                        title: "Local Library",
                        subtitle: "Sun, planets, and the Moon loaded from bundled JSON.",
                        systemImage: "circle.grid.cross",
                        value: "\(appState.celestialBodies.count)"
                    )
                }
            }
        }
    }
}
