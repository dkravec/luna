import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: LunaAppState

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.section) {
                PageHeader(
                    title: "Luna",
                    subtitle: "Explore planets, compare scale, and step into space with AR."
                )

                primaryActions

                overviewSection
            }
            .screenContentPadding()
        }
        .appBackground()
    }

    private var primaryActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Explore")

            CardSection {
                Button {
                    appState.selectedTab = .solarSystem
                } label: {
                    CardRow {
                        RowLabel(
                            title: "Solar System",
                            subtitle: "Browse bodies, facts, scale, and distance.",
                            systemImage: "sun.max",
                            showsChevron: true
                        )
                    }
                }
                .buttonStyle(.plain)
                .hapticTap()

                CardDivider(leadingInset: 56)

                Button {
                    appState.selectedTab = .arExperience
                } label: {
                    CardRow {
                        RowLabel(
                            title: "Experience",
                            subtitle: "Place and view scaled planets in your space.",
                            systemImage: "arkit",
                            showsChevron: true
                        )
                    }
                }
                .buttonStyle(.plain)
                .hapticTap()
            }
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Today")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MetricTile(
                    title: "Viewing Mode",
                    value: appState.userProfile.prefersARMode ? "AR First" : "Visual First",
                    systemImage: "viewfinder"
                )
                MetricTile(
                    title: "Bodies Loaded",
                    value: "\(appState.celestialBodies.count)",
                    systemImage: "circle.grid.cross"
                )
            }
        }
    }
}
