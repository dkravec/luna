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

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.2), .black.opacity(0.86)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

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

                VStack(alignment: .leading, spacing: family == .systemSmall ? 8 : 12) {
                    HStack(alignment: .center, spacing: 10) {
                        LunaWidgetBodyVisual(
                            textureAssetName: entry.textureAssetName,
                            fallbackName: entry.bodyName,
                            hasRings: entry.hasRings,
                            size: family == .systemSmall ? 36 : 44
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.bodyName)
                                .font(family == .systemSmall ? .headline.weight(.bold) : .title3.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)

                            Text(entry.bodyType)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.70))
                                .lineLimit(1)
                        }
                    }

                    Text(entry.fact)
                        .font(family == .systemSmall ? .caption.weight(.semibold) : .headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(family == .systemSmall ? 4 : 5)
                        .minimumScaleFactor(0.78)

                    // LunaWidgetDebugBuildMarker()
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
                ZStack(alignment: .bottomLeading) {
                    LunaWidgetSpaceBackground()

                    LunaWidgetOrbitView(bodies: entry.bodies)
                        .padding(family == .systemSmall ? 14 : 22)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Solar System")
                            .font(family == .systemSmall ? .caption.weight(.bold) : .headline.weight(.bold))
                            .foregroundStyle(.white)

                        Text(entry.date, format: .dateTime.month(.abbreviated).day())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.72))

                        // LunaWidgetDebugBuildMarker()
                    }
                    .padding(family == .systemSmall ? 12 : 16)
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
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let maxDistance = bodies.map(\.distanceFromSun).max() ?? 1

            ZStack {
                ForEach(bodies.filter { $0.distanceFromSun > 0 }) { body in
                    let radius = max(13, CGFloat(sqrt(body.distanceFromSun / maxDistance)) * size * 0.42)

                    Ellipse()
                        .stroke(.white.opacity(body.id == "earth" ? 0.20 : 0.12), lineWidth: body.id == "earth" ? 1.2 : 0.8)
                        .frame(width: radius * 2, height: radius * 1.32)
                        .position(center)
                }

                Circle()
                    .fill(Color(red: 1.0, green: 0.72, blue: 0.22))
                    .frame(width: max(9, size * 0.08), height: max(9, size * 0.08))
                    .position(center)

                ForEach(bodies.filter { $0.distanceFromSun > 0 }) { body in
                    let radius = max(13, CGFloat(sqrt(body.distanceFromSun / maxDistance)) * size * 0.42)
                    let angle = body.angleRadians(on: Date())
                    let point = CGPoint(
                        x: center.x + cos(angle) * radius,
                        y: center.y + sin(angle) * radius * 0.66
                    )

                    LunaWidgetBodyVisual(
                        textureAssetName: body.textureAssetName,
                        fallbackName: body.name,
                        hasRings: body.hasRings,
                        size: max(body.displaySize, body.hasRings ? 11 : 7)
                    )
                    .position(point)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

struct LunaWidgetSpaceBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.02, blue: 0.03)

            Image("WidgetStarfield")
                .resizable()
                .lunaWidgetFullColorImage()
                .scaledToFill()
                .opacity(0.36)
                .widgetAccentable(false)
        }
    }
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
                    .stroke(.white.opacity(0.38), lineWidth: max(1, size * 0.08))
                    .frame(width: size * 1.85, height: size * 0.66)
                    .rotationEffect(.degrees(-12))
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
                .stroke(.white.opacity(0.22), lineWidth: 1)
                .frame(width: size, height: size)
        }
        .frame(width: hasRings ? size * 1.95 : size, height: max(size, hasRings ? size * 0.92 : size))
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

private struct LunaWidgetDebugBuildMarker: View {
    var body: some View {
#if DEBUG
        Text(debugText)
            .font(.system(size: 6, weight: .semibold))
            .foregroundStyle(.white.opacity(0.36))
            .lineLimit(1)
            .accessibilityHidden(true)
#else
        EmptyView()
#endif
    }

    private var debugText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "Luna \(version)(\(build))"
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
            .background(LunaWidgetSpaceBackground())
            .widgetAccentable(false)
            .lunaWidgetBackground()
    }
}

private extension View {
    @ViewBuilder
    func lunaWidgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, *) {
            containerBackground(for: .widget) {
                LunaWidgetSpaceBackground()
            }
        } else {
            background(Color.black)
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
