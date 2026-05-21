import SwiftUI

struct TodayInLunaDetailView: View {
    @EnvironmentObject private var appState: LunaAppState

    let content: HomeDailyContent
    var showsHistory = true

    private let dailyContentProvider = HomeDailyContentProvider()

    private static let sceneSettings = ExperienceSceneSettings(
        isAREnabled: false,
        sceneScaleProfile: .scaledRecommended,
        distanceScaleMode: .compressed,
        objectScaleMode: .relative,
        distanceCompression: 12,
        renderDetail: .balanced,
        orbitPlaybackSpeed: .standard,
        objectRotationSpeed: .slow,
        showLabels: false,
        showOrbits: true
    )

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                sceneCard
                metadataCard
                DetailTextCard(title: content.dailyFact.title, text: content.dailyFact.message)
                relatedFactsSection
                openInExploreButton
                historySection
            }
            .screenContentPadding()
        }
        .navigationTitle("Today in Luna")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .appBackground()
    }

    @ViewBuilder
    private var sceneCard: some View {
        DetailMediaCard {
            if let body = content.featuredBody {
                SolarSystemVisualSceneView(
                    bodies: appState.celestialBodies.isEmpty ? [body] : appState.celestialBodies,
                    settings: Self.sceneSettings,
                    content: .object(body.id),
                    simulationDate: content.date
                )
                .frame(height: 360)
                .padding(10)
            } else {
                TodayInLunaPlaceholderCard(systemImage: content.dailyFact.systemImage)
                    .frame(height: 260)
                    .padding(10)
            }
        }
    }

    private var metadataCard: some View {
        DetailMetadataCard {
            Text(content.date, format: .dateTime.month(.wide).day().year())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(content.featuredBody?.name ?? "Today in Luna")
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let body = content.featuredBody {
                Label(body.type.title, systemImage: body.type.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(body.summary.isEmpty ? body.subtitle : body.summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var relatedFactsSection: some View {
        let facts = content.relatedFacts.filter { $0.message != content.dailyFact.message }
        if !facts.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Related Facts")

                CardSection {
                    ForEach(Array(facts.enumerated()), id: \.offset) { index, fact in
                        CardRow {
                            RowLabel(
                                title: fact.title,
                                subtitle: fact.message,
                                systemImage: fact.systemImage
                            )
                        }

                        if index < facts.count - 1 {
                            CardDivider(leadingInset: 56)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var openInExploreButton: some View {
        if let body = content.featuredBody {
            NavigationLink {
                BodyDetailView(
                    celestialBody: body,
                    childBodies: appState.celestialBodies.filter { $0.parentBodyId == body.id }
                )
            } label: {
                Label("Open in Explore", systemImage: "sun.max")
            }
            .primaryActionButton()
        }
    }

    @ViewBuilder
    private var historySection: some View {
        if showsHistory {
            let history = dailyContentProvider
                .history(for: appState.celestialBodies, endingAt: content.date, days: 8)
                .filter { !Calendar.current.isDate($0.date, inSameDayAs: content.date) }

            if !history.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "History")

                    CardSection {
                        ForEach(Array(history.enumerated()), id: \.element.date) { index, item in
                            NavigationLink {
                                TodayInLunaDetailView(content: item, showsHistory: false)
                                    .environmentObject(appState)
                            } label: {
                                CardRow {
                                    HStack(alignment: .center, spacing: 12) {
                                        IconBadge(systemImage: item.dailyFact.systemImage)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.featuredBody?.name ?? "Today in Luna")
                                                .font(.headline)
                                                .foregroundStyle(.primary)

                                            Text(item.date.formatted(date: .abbreviated, time: .omitted))
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer(minLength: 8)

                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)

                            if index < history.count - 1 {
                                CardDivider(leadingInset: 56)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct TodayInLunaPlaceholderCard: View {
    let systemImage: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Palette.spaceBlack,
                    Palette.orbitBlue.opacity(0.62),
                    Palette.moonGrey.opacity(0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: systemImage)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
        }
        .clipShape(RoundedRectangle(cornerRadius: Radii.tile, style: .continuous))
    }
}

private extension CelestialBodyType {
    var systemImage: String {
        switch self {
        case .star:
            return "sun.max"
        case .planet:
            return "circle"
        case .moon:
            return "moon"
        case .satellite:
            return "dot.radiowaves.left.and.right"
        case .rocket:
            return "airplane.departure"
        case .spacecraft:
            return "sparkles"
        case .station:
            return "rectangle.connected.to.line.below"
        case .astronaut:
            return "person"
        case .asteroid:
            return "seal"
        case .dwarfPlanet:
            return "circle.dotted"
        }
    }
}
