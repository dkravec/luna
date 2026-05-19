import SwiftUI

#if os(iOS)
import UIKit
private typealias BundledImage = UIImage
#elseif os(macOS)
import AppKit
private typealias BundledImage = NSImage
#endif

struct HomeView: View {
    @EnvironmentObject private var appState: LunaAppState

    private let dailyContentProvider = HomeDailyContentProvider()

    private enum ScrollAnchor {
        static let overview = "home.overview"
        static let exploreAction = "home.exploreAction"
    }

    var body: some View {
        let offsetDate = Calendar.current.date(byAdding: .day, value: appState.dailyFactOffset, to: Date()) ?? Date()
        let dailyContent = dailyContentProvider.content(for: appState.celestialBodies, date: offsetDate)

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.section) {
                    homeIntroSection

                    featuredBodySection(dailyContent.featuredBody)

                    factOfTheDaySection(dailyContent.dailyFact, featuredBody: dailyContent.featuredBody)

                    primaryActions

                    NASAImageOfTheDayView()

                    overviewSection
                }
                .screenContentPadding()
            }
            .appBackground()
            .onAppear {
                scrollForGuidedTourStep(appState.guidedTourStep, proxy: proxy)
            }
            .onChange(of: appState.guidedTourStep) { step in
                scrollForGuidedTourStep(step, proxy: proxy)
            }
        }
    }

    @ViewBuilder
    private var homeIntroSection: some View {
        VStack(alignment: .leading, spacing: Spacing.section) {
            PageHeader(
                title: "Luna",
                subtitle: "Explore planets, compare scale, and step into space with AR."
            )
            .guidedTourTarget(.homeOverview)

            miniSolarSystemPreview
        }
        .id(ScrollAnchor.overview)
    }

    @ViewBuilder
    private var miniSolarSystemPreview: some View {
        if !appState.celestialBodies.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    SectionHeader(title: "Solar System", subtitle: "An overhead view of Luna's local catalog.")

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

                HomeSolarSystemPreview(
                    bodies: appState.celestialBodies,
                    date: Date()
                )
                .frame(height: 240)
            }
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
                            BodyCardVisual(celestialBody: body, size: 82)

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

    private func factOfTheDaySection(_ fact: HomeDailyFact, featuredBody: CelestialBody?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: fact.title)

            Card {
                HStack(alignment: .top, spacing: 12) {
                    if let body = featuredBody {
                        BodyCardVisual(celestialBody: body, size: 72)
                    } else {
                        IconBadge(systemImage: fact.systemImage)
                    }

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
                    if !appState.guidedTourTargetTapped(.homeExploreAction) {
                        appState.selectedTab = .solarSystem
                    }
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
                .guidedTourTarget(.homeExploreAction)
                .id(ScrollAnchor.exploreAction)

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
                .guidedTourTarget(.homeExperienceAction)
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

    private func scrollForGuidedTourStep(_ step: GuidedTourStep?, proxy: ScrollViewProxy) {
        guard let step else { return }

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.25)) {
                switch step {
                case .homeWelcome:
                    proxy.scrollTo(ScrollAnchor.overview, anchor: .top)
                case .homeExplore:
                    proxy.scrollTo(ScrollAnchor.exploreAction, anchor: .center)
                default:
                    break
                }
            }
        }
    }

}

private struct HomeSolarSystemPreview: View {
    let bodies: [CelestialBody]
    let date: Date

    private var solarSystemBodies: [CelestialBody] {
        bodies
            .filter { body in
                body.type == .star
                    || body.type == .planet
                    || body.type == .dwarfPlanet
                    || body.type == .asteroid
            }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { proxy in
                let size = min(proxy.size.width, proxy.size.height)
                let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                let maxOrbitRadius = size * 0.42
                let placements = planetPlacements(maxOrbitRadius: maxOrbitRadius)

                ZStack {
                    LinearGradient(
                        colors: [
                            Palette.spaceBlack,
                            Palette.orbitBlue.opacity(0.36)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    ForEach(placements) { placement in
                        Circle()
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                            .frame(width: placement.orbitRadius * 2, height: placement.orbitRadius * 2)
                            .position(center)
                    }

                    ForEach(placements) { placement in
                        BodyVisual(celestialBody: placement.body, size: placement.bodySize)
                            .position(
                                x: center.x + cos(placement.angle) * placement.orbitRadius,
                                y: center.y + sin(placement.angle) * placement.orbitRadius
                            )
                    }

                    if let sun = solarSystemBodies.first(where: { $0.type == .star }) {
                        BodyVisual(celestialBody: sun, size: max(34, size * 0.16))
                            .position(center)
                    }
                }
            }

            Text(date.formatted(.dateTime.year().month(.abbreviated).day()))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.90))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.black.opacity(0.42), in: Capsule(style: .continuous))
                .padding(12)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radii.card, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Overhead solar system preview for \(date.formatted(.dateTime.year().month(.abbreviated).day()))")
    }

    private func planetPlacements(maxOrbitRadius: CGFloat) -> [HomeOrbitPlacement] {
        let orbitingBodies = solarSystemBodies.filter { $0.type != .star }
        let maxDistance = orbitingBodies
            .compactMap(\.averageDistanceFromSunKm)
            .max() ?? 1

        return orbitingBodies.enumerated().map { index, body in
            let normalizedDistance = max(0.08, min((body.averageDistanceFromSunKm ?? 0) / maxDistance, 1))
            let orbitRadius = maxOrbitRadius * CGFloat(pow(normalizedDistance, 0.34))
            let angle = CGFloat(index) * 1.62 + CGFloat(dayOfYear) * 0.012
            let bodySize = max(10, min(24, CGFloat(log10(max(body.radiusKm, 1))) * 4.2))

            return HomeOrbitPlacement(
                id: body.id,
                body: body,
                orbitRadius: orbitRadius,
                angle: angle,
                bodySize: bodySize
            )
        }
    }

    private var dayOfYear: Int {
        Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
    }
}

private struct HomeOrbitPlacement: Identifiable {
    let id: String
    let body: CelestialBody
    let orbitRadius: CGFloat
    let angle: CGFloat
    let bodySize: CGFloat
}
