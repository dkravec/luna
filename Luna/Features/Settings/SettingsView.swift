import SwiftUI

struct SettingsView: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                generalSection
                experienceSection
                profileSection
            }
            .screenContentPadding()
        }
        .appBackground()
        .navigationTitle("Settings")
    }

    private var experienceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Experience")

            CardSection {
                CardRow {
                    RowLabel(
                        title: "Default View",
                        subtitle: "Open Luna with AR as the preferred experience",
                        systemImage: "arkit",
                        value: "AR first"
                    )
                }

                CardDivider(leadingInset: 56)

                CardRow {
                    RowLabel(
                        title: "Scale Mode",
                        subtitle: "Keep early browsing readable until scale controls ship",
                        systemImage: "scale.3d",
                        value: "Educational"
                    )
                }

                CardDivider(leadingInset: 56)

                CardRow {
                    RowLabel(
                        title: "Labels",
                        subtitle: "Show names and values in visual scenes",
                        systemImage: "tag",
                        value: "On"
                    )
                }
            }
        }
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Profile")

            CardSection {
                CardRow {
                    RowLabel(
                        title: "Display Name",
                        subtitle: "Optional profile setup arrives with onboarding",
                        systemImage: "textformat",
                        value: "Not set"
                    )
                }

                CardDivider(leadingInset: 56)

                CardRow {
                    RowLabel(
                        title: "Reset Onboarding",
                        subtitle: "Available after local profile storage is wired",
                        systemImage: "arrow.counterclockwise",
                        value: "Phase 4"
                    )
                }
            }
        }
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "General")

            CardSection {
                NavigationLink {
                    AboutView()
                        .appBackground()
                } label: {
                    CardRow {
                        RowLabel(
                            title: "About",
                            subtitle: "Version, build, and project details",
                            systemImage: "info.circle",
                            showsChevron: true
                        )
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                appIdentityCard

                appSection

                websiteSection

                projectSection
            }
            .screenContentPadding()
        }
        .appBackground()
        .navigationTitle("About")
    }

    private var appIdentityCard: some View {
        Card {
            HStack(spacing: 12) {
                Image(systemName: "moon.stars.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Luna")
                        .font(.headline)

                    Text("Explore planets, scale, and space in AR.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var appSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "App")

            CardSection {
                CardRow {
                    aboutRow(title: "Version", value: appVersion)
                }

                CardDivider()

                CardRow {
                    aboutRow(title: "Build", value: appBuild)
                }
            }
        }
    }

    private var websiteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Website")

            Card {
                Link(destination: URL(string: "https://novapro.net")!) {
                    HStack {
                        Label("novapro.net", systemImage: "globe")
                            .font(.subheadline.weight(.semibold))

                        Spacer(minLength: 8)

                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var projectSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Project")

            Card {
                Text("Luna is an AR space app developed by Daniel Kravec at Nova Productions. This b14 rewrite is rebuilding the app for iOS, iPadOS, and macOS with AR as a main experience and a non-AR visual mode for every platform.")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }

        return "Unknown"
    }

    private var appBuild: String {
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return build
        }

        return "Unknown"
    }

    private func aboutRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }
}
