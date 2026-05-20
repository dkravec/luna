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

                    NASAImageOfTheDayView()

                    dailyContentSection(dailyContent)

//                    overviewSection
                    
                    primaryActions
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
            HStack(alignment: .top, spacing: 12) {
                PageHeader(
                    title: "Luna",
                    subtitle: "Explore planets, compare scale, and step into space with AR."
                )
                .guidedTourTarget(.homeOverview)

                Spacer(minLength: 8)

                Button {
                    appState.selectedTab = .settings
                } label: {
                    Image(systemName: "gearshape")
                        .font(.headline.weight(.semibold))
                        .frame(width: 42, height: 42)
                        .background(Color.primary.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open Settings")
                .hapticTap()
            }

            miniSolarSystemPreview
        }
        .id(ScrollAnchor.overview)
    }

    @ViewBuilder
    private var miniSolarSystemPreview: some View {
        if !appState.celestialBodies.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    SectionHeader(title: "Solar System")

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
    private func dailyContentSection(_ content: HomeDailyContent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Today In Luna")

            if let body = content.featuredBody {
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
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(content.dailyFact.message)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.top, 2)
                                    .accessibilityIdentifier("home.dailyFact")
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
                Card {
                    HStack(alignment: .top, spacing: 12) {
                        IconBadge(systemImage: content.dailyFact.systemImage)

                        Text(content.dailyFact.message)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
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
                    proxy.scrollTo(ScrollAnchor.exploreAction, anchor: .bottom)
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

    private static let previewSettings = ExperienceSceneSettings(
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
                let snapshot = ExperienceSceneEngine.snapshot(
                    for: solarSystemBodies,
                    settings: Self.previewSettings,
                    simulationDate: date
                )
                let layout = HomeSolarSystemPreviewLayout(snapshot: snapshot, size: proxy.size)

                ZStack {
                    LinearGradient(
                        colors: [
                            Palette.spaceBlack,
                            Palette.orbitBlue.opacity(0.36)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    ForEach(layout.orbits) { orbit in
                        Path { path in
                            guard let first = orbit.points.first else { return }
                            path.move(to: first)
                            for point in orbit.points.dropFirst() {
                                path.addLine(to: point)
                            }
                            path.closeSubpath()
                        }
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    }

                    ForEach(layout.placements) { placement in
                        BodyVisual(celestialBody: placement.body, size: placement.bodySize)
                            .position(placement.position)
                    }

                    if let sun = layout.sun {
                        BodyVisual(celestialBody: sun.body, size: sun.bodySize)
                            .position(sun.position)
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

}

private struct HomeOrbitPlacement: Identifiable {
    let id: String
    let body: CelestialBody
    let bodySize: CGFloat
    let position: CGPoint
}

private struct HomeOrbitPathPlacement: Identifiable {
    let id: String
    let points: [CGPoint]
}

private struct HomeSolarSystemPreviewLayout {
    let placements: [HomeOrbitPlacement]
    let orbits: [HomeOrbitPathPlacement]
    let sun: HomeOrbitPlacement?

    init(snapshot: ExperienceSceneSnapshot, size: CGSize) {
        let bounds = snapshot.bounds
        let margin = max(min(size.width, size.height) * 0.10, 18)
        let availableWidth = max(size.width - margin * 2, 1)
        let availableHeight = max(size.height - margin * 2, 1)
        let projectedBounds = Self.projectedBounds(for: snapshot, bounds: bounds)
        let scale = min(
            availableWidth / CGFloat(max(bounds.size.x, 0.001)),
            availableHeight / CGFloat(max(projectedBounds.height, 0.001))
        )
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        func project(_ point: SIMD3<Float>) -> CGPoint {
            let projectedY = Self.projectedY(point)
            return CGPoint(
                x: center.x + CGFloat(point.x - bounds.center.x) * scale,
                y: center.y + CGFloat(projectedY - projectedBounds.midY) * scale
            )
        }

        let bodyPlacements = snapshot.bodies.map { body in
            HomeOrbitPlacement(
                id: body.id,
                body: body.body,
                bodySize: Self.bodySize(for: body, canvasSize: min(size.width, size.height)),
                position: project(body.position)
            )
        }

        placements = bodyPlacements.filter { $0.body.type != .star }
        sun = bodyPlacements.first { $0.body.type == .star }
        orbits = snapshot.orbitPaths.map { path in
            HomeOrbitPathPlacement(
                id: path.id,
                points: path.points.map(project)
            )
        }
    }

    private static func bodySize(for body: ExperienceSceneBody, canvasSize: CGFloat) -> CGFloat {
        if body.body.type == .star {
            return max(10, min(16, canvasSize * 0.6))
        }

        let sourceSize = CGFloat(log10(max(body.body.radiusKm, 1))) * 4.2
        return max(10, min(16, sourceSize))
    }

    private static func projectedY(_ point: SIMD3<Float>) -> Float {
        point.z * tiltCosine - point.y * tiltSine
    }

    private static func projectedBounds(for snapshot: ExperienceSceneSnapshot, bounds: ExperienceSceneBounds) -> (midY: Float, height: Float) {
        let projectedValues = snapshot.bodies.map { projectedY($0.position) }
            + snapshot.orbitPaths.flatMap { $0.points.map(projectedY) }

        guard let minY = projectedValues.min(), let maxY = projectedValues.max() else {
            return (projectedY(bounds.center), max(bounds.size.z * tiltCosine, 0.001))
        }

        return ((minY + maxY) / 2, max(maxY - minY, 0.001))
    }

    private static let tiltCosine = Float(cos(Double.pi / 4))
    private static let tiltSine = Float(sin(Double.pi / 4))
}
