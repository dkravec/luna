import SwiftUI
import WidgetKit
#if os(iOS)
import UIKit
private typealias PlatformWidgetImage = UIImage
#elseif os(macOS)
import AppKit
private typealias PlatformWidgetImage = NSImage
#endif

struct NASAImageWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: NASAImageEntry

    var body: some View {
        LunaWidgetContainer {
            GeometryReader { proxy in
                ZStack(alignment: .bottomLeading) {
                    image
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()

                    // LinearGradient(
                    //     // colors: [.clear, .black.opacity(0.2), .black.opacity(0.86)],
                    //     startPoint: .top,
                    //     endPoint: .bottom
                    // )

                    textBlock
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, bottomPadding)
                        .frame(width: proxy.size.width, alignment: .leading)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.subtitle)
                .font(subtitleFont)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(entry.title)
                .font(titleFont)
                .foregroundStyle(.white)
                .lineLimit(titleLineLimit)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
        }
        .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 1)
        .dynamicTypeSize(...DynamicTypeSize.large)
    }

    private var subtitleFont: Font {
        switch family {
        case .systemLarge:
            return .system(size: 11, weight: .semibold)
        default:
            return .system(size: 10, weight: .semibold)
        }
    }

    private var titleFont: Font {
        switch family {
        case .systemSmall:
            return .system(size: 15, weight: .bold)
        case .systemMedium:
            return .system(size: 17, weight: .bold)
        case .systemLarge:
            return .system(size: 22, weight: .bold)
        default:
            return .headline.weight(.bold)
        }
    }

    private var titleLineLimit: Int {
        switch family {
        case .systemSmall, .systemMedium:
            return 2
        case .systemLarge:
            return 3
        default:
            return 2
        }
    }

    private var horizontalPadding: CGFloat {
        family == .systemSmall ? 12 : 16
    }

    private var bottomPadding: CGFloat {
        family == .systemSmall ? 12 : 16
    }

    @ViewBuilder
    private var image: some View {
        if let imageData = entry.imageData {
#if os(iOS)
            if let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .lunaWidgetFullColorImage()
                    .scaledToFill()
            } else {
                placeholder
            }
#elseif os(macOS)
            if let image = NSImage(data: imageData) {
                Image(nsImage: image)
                    .resizable()
                    .lunaWidgetFullColorImage()
                    .scaledToFill()
            } else {
                placeholder
            }
#else
            placeholder
#endif
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            LunaWidgetSpaceBackground()

            Image(systemName: "sparkles")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
                .widgetAccentable(false)
        }
    }
}

struct LunaFactWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: LunaFactEntry

    var body: some View {
        LunaWidgetContainer {
            GeometryReader { proxy in
                VStack(alignment: .leading, spacing: factSpacing) {
                    factHeader

                    Text(entry.fact)
                        .font(factFont)
                        .foregroundStyle(.white.opacity(0.84))
                        .lineLimit(factLineLimit)
                        .minimumScaleFactor(family == .systemSmall ? 0.76 : 0.84)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .layoutPriority(1)
                }
                .padding(factPadding)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                .dynamicTypeSize(...DynamicTypeSize.large)
            }
        }
    }

    @ViewBuilder
    private var factHeader: some View {
        if family == .systemSmall {
            VStack(alignment: .leading, spacing: 6) {
                LunaWidgetBodyVisual(
                    textureAssetName: entry.textureAssetName,
                    thumbnailName: entry.thumbnailName,
                    fallbackName: entry.bodyName,
                    hasRings: entry.hasRings,
                    size: 30
                )

                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.bodyName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.93))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(entry.bodyType)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .top, spacing: 10) {
                LunaWidgetBodyVisual(
                    textureAssetName: entry.textureAssetName,
                    thumbnailName: entry.thumbnailName,
                    fallbackName: entry.bodyName,
                    hasRings: entry.hasRings,
                    size: 44
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.bodyName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white.opacity(0.93))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(entry.bodyType)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
            }
        }
    }

    private var factPadding: CGFloat {
        family == .systemSmall ? 12 : 18
    }

    private var factSpacing: CGFloat {
        family == .systemSmall ? 7 : 12
    }

    private var factFont: Font {
        family == .systemSmall ? .caption2.weight(.semibold) : .headline.weight(.semibold)
    }

    private var factLineLimit: Int {
        family == .systemSmall ? 4 : 5
    }
}

struct LunaSolarOverviewWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: LunaSolarOverviewEntry

    var body: some View {
        LunaWidgetContainer {
            GeometryReader { proxy in
                let metrics = solarMetrics(for: proxy.size)

                VStack(alignment: .leading, spacing: metrics.spacing) {
                    solarHeader
                        .frame(maxWidth: .infinity, minHeight: metrics.headerHeight, alignment: .topLeading)
                        .layoutPriority(1)

                    LunaWidgetOrbitView(bodies: entry.bodies, date: entry.date)
                        .padding(metrics.orbitInsets)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(metrics.contentInsets)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .dynamicTypeSize(...DynamicTypeSize.large)
            }
        }
    }

    private var solarHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Solar System")
                .font(family == .systemSmall ? .caption.weight(.bold) : .headline.weight(.bold))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(entry.date, format: .dateTime.month(.abbreviated).day())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func solarMetrics(for size: CGSize) -> SolarWidgetMetrics {
        switch family {
        case .systemSmall:
            return SolarWidgetMetrics(
                contentInsets: EdgeInsets(top: 11, leading: 11, bottom: 11, trailing: 11),
                orbitInsets: EdgeInsets(top: 1, leading: 6, bottom: 2, trailing: 6),
                headerHeight: 29,
                spacing: 2
            )
        case .systemLarge:
            return SolarWidgetMetrics(
                contentInsets: EdgeInsets(top: 16, leading: 16, bottom: 18, trailing: 16),
                orbitInsets: EdgeInsets(top: 8, leading: 24, bottom: 12, trailing: 24),
                headerHeight: 42,
                spacing: 8
            )
        default:
            let horizontal = max(18, min(28, size.width * 0.07))
            return SolarWidgetMetrics(
                contentInsets: EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16),
                orbitInsets: EdgeInsets(top: 3, leading: horizontal, bottom: 5, trailing: horizontal),
                headerHeight: 34,
                spacing: 4
            )
        }
    }
}

private struct LunaWidgetOrbitView: View {
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

    var body: some View {
        GeometryReader { proxy in
            let snapshot = ExperienceSceneEngine.snapshot(
                for: solarSystemBodies,
                settings: Self.previewSettings,
                simulationDate: date
            )
            let layout = LunaSolarPreviewLayout(
                snapshot: snapshot,
                size: proxy.size,
                bodySize: LunaSolarPreviewLayout.widgetBodySize(for:canvasSize:)
            )

            ZStack {
                ForEach(layout.orbits) { orbit in
                    Path { path in
                        guard let first = orbit.points.first else { return }
                        path.move(to: first)
                        for point in orbit.points.dropFirst() {
                            path.addLine(to: point)
                        }
                        path.closeSubpath()
                    }
                    .stroke(.white.opacity(orbit.isInner ? 0.13 : 0.09), lineWidth: orbit.isInner ? 0.9 : 0.7)
                    .widgetAccentable(false)
                }

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 1.0, green: 0.76, blue: 0.28).opacity(0.95),
                                Color(red: 0.95, green: 0.40, blue: 0.12).opacity(0.72)
                            ],
                            center: .center,
                            startRadius: 1,
                            endRadius: layout.sunSize / 2
                        )
                    )
                    .frame(width: layout.sunSize, height: layout.sunSize)
                    .shadow(color: Color.orange.opacity(0.28), radius: 8)
                    .position(layout.center)
                    .widgetAccentable(false)

                ForEach(layout.placements) { placement in
                    let body = LunaWidgetBodySnapshot(body: placement.body)
                    LunaWidgetBodyVisual(
                        textureAssetName: body.textureAssetName,
                        thumbnailName: body.thumbnailName,
                        fallbackName: body.name,
                        hasRings: body.hasRings,
                        size: placement.bodySize
                    )
                    .position(placement.position)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

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
}

struct LunaWidgetSpaceBackground: View {
    var body: some View {
        GeometryReader { proxy in
            Image("WidgetStarfield")
                .resizable()
                .lunaWidgetFullColorImage()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .opacity(0.20)
                .widgetAccentable(false)
        }
    }
}

private struct LunaWidgetBodyVisual: View {
    let textureAssetName: String?
    var thumbnailName: String? = nil
    let fallbackName: String
    let hasRings: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            if hasRings {
                LunaWidgetSaturnRingVisual(size: size)
            }

            if let textureAssetName {
                Image(textureAssetName)
                    .resizable()
                    .lunaWidgetFullColorImage()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if let thumbnailName, let image = thumbnailImage(named: thumbnailName) {
#if os(iOS)
                Image(uiImage: image)
                    .resizable()
                    .lunaWidgetFullColorImage()
                    .scaledToFit()
                    .frame(width: size * 1.26, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: max(3, size * 0.14), style: .continuous))
#elseif os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .lunaWidgetFullColorImage()
                    .scaledToFit()
                    .frame(width: size * 1.26, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: max(3, size * 0.14), style: .continuous))
#endif
            } else {
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
            }

            Circle()
                .stroke(.white.opacity(0.16), lineWidth: 1)
                .frame(width: size, height: size)
        }
        .frame(
            width: hasRings ? size * LunaSaturnRingMetrics.outerRadiusRatio : size,
            height: max(size, hasRings ? size * LunaSaturnRingMetrics.outerRadiusRatio * LunaSaturnRingMetrics.ellipseHeightRatio : size)
        )
        .widgetAccentable(false)
    }

    private func thumbnailImage(named thumbnailName: String) -> PlatformWidgetImage? {
        guard let url = LunaWidgetThumbnailResourceResolver.url(named: thumbnailName) else { return nil }

#if os(iOS)
        return PlatformWidgetImage(contentsOfFile: url.path)
#elseif os(macOS)
        return PlatformWidgetImage(contentsOf: url)
#endif
    }

    private var color: Color {
        switch fallbackName.lowercased() {
        case "mercury", "moon":
            return .gray
        case "venus", "saturn":
            return .yellow
        case "earth", "uranus", "neptune":
            return .blue
        case "mars":
            return .red
        case "jupiter":
            return .orange
        default:
            return .white.opacity(0.72)
        }
    }
}

private struct LunaWidgetSaturnRingVisual: View {
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
        .widgetAccentable(false)
    }
}

private struct LunaWidgetContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .widgetAccentable(false)
            .lunaWidgetBackground {
                LunaWidgetSpaceBackground()
            }

    }
}

private struct SolarWidgetMetrics {
    let contentInsets: EdgeInsets
    let orbitInsets: EdgeInsets
    let headerHeight: CGFloat
    let spacing: CGFloat
}

private extension View {
    @ViewBuilder
    func lunaWidgetBackground<Background: View>(@ViewBuilder _ background: () -> Background) -> some View {
        if #available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, *) {
            self.containerBackground(for: .widget) {
                background()
            }
        } else {
            self.background(background())
        }
    }

}

private extension Image {
    @ViewBuilder
    func lunaWidgetFullColorImage() -> some View {
        if #available(iOSApplicationExtension 18.0, macOSApplicationExtension 15.0, watchOSApplicationExtension 11.0, *) {
            self.widgetAccentedRenderingMode(.fullColor)
        } else {
            self
        }
    }
}
