import SwiftUI
import WidgetKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
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
            ZStack(alignment: .topLeading) {
                LunaWidgetSpaceBackground()

                VStack(alignment: .leading, spacing: family == .systemSmall ? 10 : 12) {
                    if family == .systemSmall {
                        VStack(alignment: .leading, spacing: 8) {
                            LunaWidgetBodyVisual(
                                textureAssetName: entry.textureAssetName,
                                fallbackName: entry.bodyName,
                                hasRings: entry.hasRings,
                                size: 34
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.bodyName)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.white.opacity(0.92))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(entry.bodyType)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.58))
                                    .lineLimit(1)
                            }
                        }
                    } else {
                        HStack(alignment: .top, spacing: 10) {
                            LunaWidgetBodyVisual(
                                textureAssetName: entry.textureAssetName,
                                fallbackName: entry.bodyName,
                                hasRings: entry.hasRings,
                                size: 44
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.bodyName)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.white.opacity(0.92))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.78)

                                Text(entry.bodyType)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.58))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .layoutPriority(1)
                        }
                    }

                    Text(entry.fact)
                        .font(family == .systemSmall ? .caption.weight(.semibold) : .headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(family == .systemSmall ? 4 : 5)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(family == .systemSmall ? 14 : 18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct LunaSolarOverviewWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: LunaSolarOverviewEntry

    var body: some View {
        LunaWidgetContainer {
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    LunaWidgetSpaceBackground()

                    LunaWidgetOrbitView(bodies: entry.bodies)
                        .padding(.top, family == .systemSmall ? 34 : 40)
                        .padding(.horizontal, family == .systemSmall ? 14 : 22)
                        .padding(.bottom, family == .systemSmall ? 14 : 22)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Solar System")
                            .font(family == .systemSmall ? .caption.weight(.bold) : .headline.weight(.bold))
                            .foregroundStyle(.white.opacity(0.90))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(entry.date, format: .dateTime.month(.abbreviated).day())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.58))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, family == .systemSmall ? 12 : 16)
                    .padding(.top, family == .systemSmall ? 12 : 16)
                    .frame(width: proxy.size.width, alignment: .leading)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }
}

private struct LunaWidgetOrbitView: View {
    let bodies: [LunaWidgetBody]

    var body: some View {
        GeometryReader { proxy in
            let layout = LunaWidgetSolarLayout(
                bodies: bodies,
                size: proxy.size,
                date: Date()
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
                    LunaWidgetBodyVisual(
                        textureAssetName: placement.body.textureAssetName,
                        fallbackName: placement.body.name,
                        hasRings: placement.body.hasRings,
                        size: placement.size
                    )
                    .position(placement.position)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

struct LunaWidgetSpaceBackground: View {
    var body: some View {
        ZStack {
            // Color(red: 0.012, green: 0.013, blue: 0.020)

            Image("WidgetStarfield")
                .resizable()
                .lunaWidgetFullColorImage()
                .scaledToFill()
                .opacity(0.20)
                .widgetAccentable(false)
        }
    }
}

private struct LunaWidgetSolarLayout {
    struct Orbit: Identifiable {
        let id: String
        let points: [CGPoint]
        let isInner: Bool
    }

    struct Placement: Identifiable {
        let id: String
        let body: LunaWidgetBody
        let position: CGPoint
        let size: CGFloat
    }

    let center: CGPoint
    let sunSize: CGFloat
    let orbits: [Orbit]
    let placements: [Placement]

    init(bodies: [LunaWidgetBody], size: CGSize, date: Date) {
        let canvas = max(min(size.width, size.height), 1)
        let margin = max(canvas * 0.09, 12)
        let maxDistance = max(bodies.map(\.distanceFromSun).max() ?? 1, 1)
        let centerPoint = CGPoint(x: size.width / 2, y: size.height / 2)
        let computedSunSize = max(9, min(18, canvas * 0.095))
        let maxRadius = max(min(size.width, size.height) / 2 - margin, 1)

        func expandedRadius(for body: LunaWidgetBody) -> CGFloat {
            let normalized = min(max(body.distanceFromSun / maxDistance, 0), 1)
            return max(canvas * 0.12, CGFloat(pow(normalized, 0.38)) * maxRadius)
        }

        func project(radius: CGFloat, angle: Double) -> CGPoint {
            CGPoint(
                x: centerPoint.x + cos(angle) * radius,
                y: centerPoint.y + sin(angle) * radius * Self.tiltScale
            )
        }

        let planetBodies = bodies.filter { $0.distanceFromSun > 0 }
        let computedOrbits = planetBodies.map { body in
            let radius = expandedRadius(for: body)
            let points = stride(from: 0, to: Self.pathSegments, by: 1).map { index in
                project(
                    radius: radius,
                    angle: Double(index) / Double(Self.pathSegments) * .pi * 2
                )
            }
            return Orbit(id: body.id, points: points, isInner: body.distanceFromSun <= 230)
        }

        let computedPlacements = planetBodies.map { body in
            let radius = expandedRadius(for: body)
            let point = project(radius: radius, angle: body.angleRadians(on: date))
            return Placement(
                id: body.id,
                body: body,
                position: point,
                size: max(body.displaySize, body.hasRings ? 10 : 6)
            )
        }

        center = centerPoint
        sunSize = computedSunSize
        orbits = computedOrbits
        placements = computedPlacements
    }

    private static let tiltScale: CGFloat = 0.56
    private static let pathSegments = 96
}

private struct LunaWidgetBodyVisual: View {
    let textureAssetName: String?
    let fallbackName: String
    let hasRings: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            if hasRings {
                Ellipse()
                    .stroke(.white.opacity(0.28), lineWidth: max(1, size * 0.08))
                    .frame(width: size * 1.85, height: size * 0.66)
                    .rotationEffect(.degrees(-12))
                    .widgetAccentable(false)
            }

            if let textureAssetName {
                Image(textureAssetName)
                    .resizable()
                    .lunaWidgetFullColorImage()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
            }

            Circle()
                .stroke(.white.opacity(0.16), lineWidth: 1)
                .frame(width: size, height: size)
        }
        .frame(width: hasRings ? size * 1.95 : size, height: max(size, hasRings ? size * 0.92 : size))
        .widgetAccentable(false)
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

private struct LunaWidgetContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .widgetAccentable(false)
            .lunaWidgetBackground()

    }
}

private extension View {
    @ViewBuilder
    func lunaWidgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, *) {
            containerBackground(for: .widget) {
                Color.clear
            }
        } else {
            background(Color.clear)
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
