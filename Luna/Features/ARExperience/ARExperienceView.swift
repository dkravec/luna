import SwiftUI

struct ARExperienceView: View {
    @EnvironmentObject private var appState: LunaAppState

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.section) {
                PageHeader(
                    title: "AR Experience",
                    subtitle: "Place scaled worlds in your space or browse in visual mode."
                )

                modeSection

                controlsSection
            }
            .screenContentPadding()
        }
        .appBackground()
    }

    private var modeSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    IconBadge(systemImage: "viewfinder")

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ready for AR")
                            .font(.headline)

                        Text("Visual mode stays available when AR is off or unsupported.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                    } label: {
                        Label("Start AR", systemImage: "arkit")
                    }
                    .primaryActionButton()
                    .disabled(true)

                    Button {
                    } label: {
                        Label("Visual", systemImage: "cube.transparent")
                    }
                    .secondaryActionButton()
                    .disabled(true)
                }
            }
        }
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Scene Controls")

            CardSection {
                CardRow {
                    RowLabel(
                        title: "Planet Size",
                        subtitle: "Scale up small bodies without changing distance labels.",
                        systemImage: "plus.magnifyingglass",
                        value: "1x"
                    )
                }

                CardDivider(leadingInset: 56)

                CardRow {
                    RowLabel(
                        title: "Compressed Distance",
                        subtitle: "Use an educational layout for room-scale viewing.",
                        systemImage: "arrow.down.left.and.arrow.up.right",
                        value: "Off"
                    )
                }

                CardDivider(leadingInset: 56)

                CardRow {
                    RowLabel(
                        title: "Labels",
                        subtitle: "Show body names and scale notes in the scene.",
                        systemImage: "tag",
                        value: appState.userProfile.showLabels ? "On" : "Off"
                    )
                }
            }
        }
    }
}
