import SwiftUI
#if os(iOS)
import UIKit
private typealias PlatformBodyImage = UIImage
#elseif os(macOS)
import AppKit
private typealias PlatformBodyImage = NSImage
#endif

struct BodyDetailView: View {
    @EnvironmentObject private var appState: LunaAppState

    let celestialBody: CelestialBody
    let childBodies: [CelestialBody]

    var bodyContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.section) {
                hero
                factsSection
                orbitSection
                descriptionSection
                relatedSection
            }
            .screenContentPadding()
        }
        .appBackground()
        .navigationTitle(celestialBody.name)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    @ViewBuilder
    private var orbitSection: some View {
        if let orbit = celestialBody.orbit {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Orbit")

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    MetricTile(
                        title: "Semi-major Axis",
                        value: Formatters.distance(orbit.semiMajorAxisKm),
                        systemImage: "arrow.left.and.right"
                    )

                    MetricTile(
                        title: "Eccentricity",
                        value: Formatters.decimal(orbit.eccentricity, fractionDigits: 3),
                        systemImage: "oval"
                    )

                    MetricTile(
                        title: "Inclination",
                        value: Formatters.degrees(orbit.inclinationDegrees),
                        systemImage: "angle"
                    )

                    MetricTile(
                        title: "Axial Tilt",
                        value: Formatters.degrees(celestialBody.axialTiltDegrees ?? Double(ExperienceSceneEngine.axialTiltRadians(for: celestialBody)) * 180 / .pi),
                        systemImage: "gyroscope"
                    )

                    MetricTile(
                        title: "Rotational Speed",
                        value: Formatters.rotationalSpeed(radiusKm: celestialBody.radiusKm, periodHours: celestialBody.rotationPeriodHours),
                        systemImage: "speedometer"
                    )
                }
            }
        }
    }

    var body: some View {
        bodyContent
    }

    private var hero: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                BodyPreviewSceneView(celestialBody: celestialBody)
                    .frame(height: 260)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 6) {
                    Text(celestialBody.type.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(celestialBody.name)
                        .font(.largeTitle.weight(.bold))

                    Text(celestialBody.subtitle)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if appState.guidedTourStep == .bodyDetailExperience {
                    Button {
                        _ = appState.guidedTourTargetTapped(.bodyDetailExperience)
                    } label: {
                        Label("Open Experience", systemImage: "arkit")
                            .frame(maxWidth: .infinity)
                    }
                    .primaryActionButton()
                    .guidedTourTarget(.bodyDetailExperience)
                } else {
                    NavigationLink {
                        ObjectExperienceView(celestialBody: celestialBody)
                    } label: {
                        Label("Open Experience", systemImage: "arkit")
                            .frame(maxWidth: .infinity)
                    }
                    .primaryActionButton()
                    .guidedTourTarget(.bodyDetailExperience)
                }
            }
        }
    }

    private var factsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Facts")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                MetricTile(title: "Radius", value: Formatters.distance(celestialBody.radiusKm), systemImage: "ruler")

                MetricTile(
                    title: "From Sun",
                    value: Formatters.optionalDistance(celestialBody.averageDistanceFromSunKm),
                    systemImage: "sun.max"
                )

                MetricTile(
                    title: "From Earth",
                    value: Formatters.optionalDistance(celestialBody.averageDistanceFromEarthKm),
                    systemImage: "globe.americas"
                )

                MetricTile(
                    title: "Gravity",
                    value: Formatters.optionalGravity(celestialBody.gravity),
                    systemImage: "arrow.down"
                )

                MetricTile(
                    title: "Orbital Period",
                    value: Formatters.optionalDays(celestialBody.orbitalPeriodDays),
                    systemImage: "circle.dashed"
                )

                MetricTile(
                    title: "Rotation",
                    value: Formatters.optionalHours(celestialBody.rotationPeriodHours),
                    systemImage: "rotate.3d"
                )
            }
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Overview")

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text(celestialBody.summary)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(celestialBody.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    TagCloud(tags: celestialBody.tags)
                }
            }
        }
    }

    @ViewBuilder
    private var relatedSection: some View {
        if !childBodies.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Related Bodies")

                CardSection {
                    ForEach(Array(childBodies.enumerated()), id: \.element.id) { index, child in
                        NavigationLink {
                            BodyDetailView(celestialBody: child, childBodies: [])
                        } label: {
                            CardRow {
                                RowLabel(
                                    title: child.name,
                                    subtitle: child.subtitle,
                                    systemImage: child.type.systemImage,
                                    value: child.type.title,
                                    showsChevron: true
                                )
                            }
                        }
                        .buttonStyle(.plain)
                        .hapticTap()

                        if index < childBodies.count - 1 {
                            CardDivider(leadingInset: 56)
                        }
                    }
                }
            }
        }
    }

}

struct BodyVisual: View {
    let celestialBody: CelestialBody
    var size: CGFloat = 72

    var body: some View {
        ZStack {
            if hasImage {
                bundledImage
            } else {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: placeholderColors,
                            center: .topLeading,
                            startRadius: 4,
                            endRadius: size
                        )
                    )

                Circle()
                    .stroke(Color.white.opacity(0.30), lineWidth: max(1, size * 0.018))

                if celestialBody.type == .planet || celestialBody.type == .moon {
                    Circle()
                        .trim(from: 0.10, to: 0.54)
                        .stroke(Color.white.opacity(0.20), lineWidth: max(1, size * 0.028))
                        .rotationEffect(.degrees(-18))
                        .padding(size * 0.16)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .shadow(color: placeholderColors.last?.opacity(0.28) ?? Color.clear, radius: size * 0.16, x: 0, y: size * 0.08)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var bundledImage: some View {
#if os(iOS)
        if let image = Self.textureImage(for: celestialBody) ?? Self.assetImage(named: celestialBody.imageName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        }
#elseif os(macOS)
        if let image = Self.textureImage(for: celestialBody) ?? Self.assetImage(named: celestialBody.imageName) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        }
#endif
    }

    private var hasImage: Bool {
        Self.textureImage(for: celestialBody) != nil || Self.assetImage(named: celestialBody.imageName) != nil
    }

    private var placeholderColors: [Color] {
        switch celestialBody.id {
        case "sun":
            return [Color(red: 1.0, green: 0.84, blue: 0.34), Color(red: 0.98, green: 0.36, blue: 0.14)]
        case "mercury":
            return [Color(red: 0.70, green: 0.68, blue: 0.62), Color(red: 0.35, green: 0.34, blue: 0.33)]
        case "venus":
            return [Color(red: 0.91, green: 0.74, blue: 0.45), Color(red: 0.67, green: 0.47, blue: 0.24)]
        case "earth":
            return [Color(red: 0.22, green: 0.56, blue: 0.88), Color(red: 0.18, green: 0.52, blue: 0.34)]
        case "moon":
            return [Color(red: 0.84, green: 0.84, blue: 0.80), Color(red: 0.42, green: 0.42, blue: 0.44)]
        case "mars":
            return [Color(red: 0.86, green: 0.42, blue: 0.22), Color(red: 0.45, green: 0.18, blue: 0.12)]
        case "jupiter":
            return [Color(red: 0.83, green: 0.68, blue: 0.52), Color(red: 0.55, green: 0.34, blue: 0.22)]
        case "saturn":
            return [Color(red: 0.86, green: 0.76, blue: 0.55), Color(red: 0.56, green: 0.45, blue: 0.30)]
        case "uranus":
            return [Color(red: 0.60, green: 0.86, blue: 0.88), Color(red: 0.32, green: 0.60, blue: 0.68)]
        case "neptune":
            return [Color(red: 0.28, green: 0.48, blue: 0.92), Color(red: 0.12, green: 0.22, blue: 0.58)]
        default:
            return [Palette.moonGrey, Palette.orbitBlue]
        }
    }

    private static func textureImage(for body: CelestialBody) -> PlatformBodyImage? {
        guard let textureName = body.textureName,
              let url = Bundle.main.url(
                forResource: textureName,
                withExtension: "jpg",
                subdirectory: "Planets"
              ) else {
            return nil
        }

#if os(iOS)
        return PlatformBodyImage(contentsOfFile: url.path)
#elseif os(macOS)
        return PlatformBodyImage(contentsOf: url)
#endif
    }

    private static func assetImage(named imageName: String?) -> PlatformBodyImage? {
        guard let imageName else { return nil }

#if os(iOS)
        return PlatformBodyImage(named: imageName)
#elseif os(macOS)
        return PlatformBodyImage(named: imageName)
#endif
    }
}

private struct TagCloud: View {
    let tags: [String]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag.capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06), in: Capsule(style: .continuous))
            }
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return layout(sizes: sizes, maxWidth: maxWidth).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let placements = layout(sizes: sizes, maxWidth: bounds.width).placements

        for index in subviews.indices {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + placements[index].x, y: bounds.minY + placements[index].y),
                proposal: ProposedViewSize(width: sizes[index].width, height: sizes[index].height)
            )
        }
    }

    private func layout(sizes: [CGSize], maxWidth: CGFloat) -> (size: CGSize, placements: [CGPoint]) {
        var placements: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var width: CGFloat = 0

        for size in sizes {
            if currentX > 0, currentX + size.width > maxWidth {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            placements.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            width = max(width, currentX - spacing)
        }

        return (CGSize(width: min(width, maxWidth), height: currentY + lineHeight), placements)
    }
}

private enum Formatters {
    static func distance(_ value: Double) -> String {
        if value == 0 {
            return "0 km"
        }

        if value < 1 {
            return "\(formatted(value * 1_000)) m"
        }

        if value >= 1_000_000 {
            return "\(formatted(value / 1_000_000))M km"
        }

        return "\(formatted(value)) km"
    }

    static func optionalDistance(_ value: Double?) -> String {
        guard let value else { return "Not set" }
        return distance(value)
    }

    static func optionalGravity(_ value: Double?) -> String {
        guard let value else { return "Not set" }
        return "\(formatted(value)) m/s2"
    }

    static func optionalDays(_ value: Double?) -> String {
        guard let value else { return "Not set" }
        if value >= 365 {
            return "\(formatted(value / 365.25)) years"
        }
        return "\(formatted(value)) days"
    }

    static func optionalHours(_ value: Double?) -> String {
        guard let value else { return "Not set" }
        let suffix = value < 0 ? " retrograde" : ""
        return "\(formatted(abs(value))) hrs\(suffix)"
    }

    private static func formatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value >= 100 ? 0 : 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func decimal(_ value: Double, fractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func degrees(_ value: Double) -> String {
        "\(formatted(value)) deg"
    }

    static func rotationalSpeed(radiusKm: Double, periodHours: Double?) -> String {
        guard let periodHours, periodHours != 0 else { return "Not set" }
        return "\(formatted(2 * Double.pi * radiusKm / abs(periodHours))) km/h"
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
