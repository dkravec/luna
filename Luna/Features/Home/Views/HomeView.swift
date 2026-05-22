import SwiftUI
import simd

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
        let baseDate = ScreenshotMode.isEnabled ? ScreenshotMode.fixedDate : Date()
        let offsetDate = Calendar.current.date(byAdding: .day, value: appState.dailyFactOffset, to: baseDate) ?? baseDate
        let dailyContent = dailyContentProvider.content(for: appState.celestialBodies, date: offsetDate)

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.section) {
                    homeIntroSection

                    NASAImageOfTheDayView()

                    dailyContentSection(dailyContent)

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
            .onChange(of: appState.guidedTourPresentationID) { _ in
                scrollForGuidedTourStep(appState.guidedTourStep, proxy: proxy)
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
                .guidedTourTarget(.homeOverview, when: appState.guidedTourStep == .homeWelcome)

                Spacer(minLength: 8)
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
                    date: ScreenshotMode.isEnabled ? ScreenshotMode.fixedDate : Date()
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
                    TodayInLunaDetailView(content: content)
                } label: {
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 14) {
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
                            
                            Text(content.dailyFact.message)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("home.dailyFact")
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
                .guidedTourTarget(.homeExploreAction, when: appState.guidedTourStep == .homeExplore)
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

    private func scrollForGuidedTourStep(_ step: GuidedTourStep?, proxy: ScrollViewProxy) {
        guard let step else { return }

        let anchor: UnitPoint?

        switch step {
        case .homeWelcome:
            anchor = .top
        case .homeExplore:
            anchor = .center
        default:
            anchor = nil
        }

        guard let anchor else { return }

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.25)) {
                switch step {
                case .homeWelcome:
                    proxy.scrollTo(ScrollAnchor.overview, anchor: anchor)
                case .homeExplore:
                    proxy.scrollTo(ScrollAnchor.exploreAction, anchor: anchor)
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
                    || body.type == .moon
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
                let layout = LunaSolarPreviewLayout(snapshot: snapshot, size: proxy.size)

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
                        HomeSolarBodyVisual(celestialBody: placement.body, size: placement.bodySize)
                            .position(placement.position)
                    }

                    if let sun = layout.sun {
                        HomeSolarBodyVisual(celestialBody: sun.body, size: sun.bodySize)
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

private struct HomeSolarBodyVisual: View {
    let celestialBody: CelestialBody
    let size: CGFloat

    var body: some View {
        ZStack {
            if celestialBody.id == "saturn" {
                HomeSaturnRingVisual(size: size)
            }

            BodyVisual(celestialBody: celestialBody, size: size)
        }
        .frame(
            width: celestialBody.id == "saturn" ? size * LunaSaturnRingMetrics.outerRadiusRatio : size,
            height: max(size, celestialBody.id == "saturn" ? size * LunaSaturnRingMetrics.outerRadiusRatio * LunaSaturnRingMetrics.ellipseHeightRatio : size)
        )
    }
}

private struct HomeSaturnRingVisual: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            ForEach(Array(LunaSaturnRingMetrics.bands.enumerated()), id: \.offset) { _, band in
                Ellipse()
                    .stroke(.white.opacity(band.opacity), lineWidth: max(0.6, size * band.lineWidthRatio))
                    .frame(
                        width: size * band.diameterRatio,
                        height: size * band.diameterRatio * LunaSaturnRingMetrics.ellipseHeightRatio
                    )
            }
        }
        .rotationEffect(.degrees(-12))
        .allowsHitTesting(false)
    }
}
