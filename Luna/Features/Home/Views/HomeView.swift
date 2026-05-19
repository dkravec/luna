import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: LunaAppState
    @State private var selectedPreviewBodyID: String?

    private let dailyContentProvider = HomeDailyContentProvider()

    var body: some View {
        let dailyContent = dailyContentProvider.content(for: appState.celestialBodies)

        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.section) {
                PageHeader(
                    title: "Luna",
                    subtitle: "Explore planets, compare scale, and step into space with AR."
                )

                miniSolarSystemPreview

                featuredBodySection(dailyContent.featuredBody)

                factOfTheDaySection(dailyContent.dailyFact)

                primaryActions

                NASAImageOfTheDayView()

                overviewSection
            }
            .screenContentPadding()
        }
        .appBackground()
        .background(hiddenPreviewNavigationLink)
    }

    private var isPreviewBodySelected: Binding<Bool> {
        Binding(
            get: { selectedPreviewBodyID != nil },
            set: { isSelected in
                if !isSelected {
                    selectedPreviewBodyID = nil
                }
            }
        )
    }

    @ViewBuilder
    private var hiddenPreviewNavigationLink: some View {
        if let selectedPreviewBody {
            NavigationLink(isActive: isPreviewBodySelected) {
                BodyDetailView(
                    celestialBody: selectedPreviewBody,
                    childBodies: appState.celestialBodies.filter { $0.parentBodyId == selectedPreviewBody.id }
                )
            } label: {
                EmptyView()
            }
            .hidden()
        }
    }

    private var selectedPreviewBody: CelestialBody? {
        selectedPreviewBodyID.flatMap { bodyID in
            appState.celestialBodies.first { $0.id == bodyID }
        }
    }

    @ViewBuilder
    private var miniSolarSystemPreview: some View {
        if !appState.celestialBodies.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    SectionHeader(title: "Solar System", subtitle: "A live preview of Luna's local catalog.")

                    Button {
                        appState.selectedTab = .arExperience
                    } label: {
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                            .frame(width: 30, height: 30)
                            .background(Color.primary.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open Experience")
                    .hapticTap()
                }

                if isRunningUnitTests {
                    miniPreviewTestPlaceholder
                } else {
                    SolarSystemVisualSceneView(
                        bodies: appState.celestialBodies,
                        settings: miniPreviewSettings,
                        simulationDate: Date(),
                        onSelectBody: { body in
                            selectedPreviewBodyID = body.id
                        }
                    )
                    .frame(height: 240)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var miniPreviewTestPlaceholder: some View {
        Card {
            RowLabel(
                title: "Solar System",
                subtitle: "A live preview of Luna's local catalog.",
                systemImage: "sun.max"
            )
        }
    }

    @ViewBuilder
    private func featuredBodySection(_ body: CelestialBody?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Featured Body")

            if let body {
                NavigationLink {
                    BodyDetailView(
                        celestialBody: body,
                        childBodies: appState.celestialBodies.filter { $0.parentBodyId == body.id }
                    )
                } label: {
                    Card {
                        HStack(alignment: .center, spacing: 14) {
                            BodyVisual(celestialBody: body, size: 82)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Text(body.name)
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(.primary)

                                    Text(body.type.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.primary.opacity(0.06), in: Capsule(style: .continuous))
                                }

                                Text(body.summary.isEmpty ? body.subtitle : body.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 0)

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .hapticTap()
            } else {
                EmptyStateView(
                    title: "No Featured Body",
                    systemImage: "sparkles",
                    message: "Luna could not load the local celestial body catalog."
                )
            }
        }
    }

    private func factOfTheDaySection(_ fact: HomeDailyFact) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: fact.title)

            Card {
                HStack(alignment: .top, spacing: 12) {
                    IconBadge(systemImage: fact.systemImage)

                    Text(fact.message)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
        }
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
                            title: "Explore",
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
            SectionHeader(title: "Status")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MetricTile(
                    title: "Viewing Mode",
                    value: appState.experiencePreferences.prefersARMode ? "AR First" : "Visual First",
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

    private var miniPreviewSettings: ExperienceSceneSettings {
        ExperienceSceneSettings(
            isAREnabled: false,
            sceneScaleProfile: appState.experiencePreferences.sceneScaleProfile,
            distanceScaleMode: appState.experiencePreferences.distanceScaleMode,
            objectScaleMode: appState.experiencePreferences.objectScaleMode,
            distanceCompression: appState.experiencePreferences.distanceCompression,
            renderDetail: .balanced,
            orbitPlaybackSpeed: appState.experiencePreferences.orbitPlaybackSpeed,
            objectRotationSpeed: appState.experiencePreferences.objectRotationSpeed,
            showLabels: true,
            showOrbits: true
        )
    }

    private var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
