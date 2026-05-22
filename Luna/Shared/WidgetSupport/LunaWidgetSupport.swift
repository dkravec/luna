import CoreGraphics
import Foundation
import simd

struct LunaWidgetFactContent: Equatable {
    let date: Date
    let body: LunaWidgetBodySnapshot
    let fact: String
}

struct LunaWidgetBodySnapshot: Identifiable, Equatable {
    let id: String
    let name: String
    let typeTitle: String
    let averageDistanceFromSunKm: Double?
    let averageDistanceFromEarthKm: Double?
    let orbitalPeriodDays: Double?
    let radiusKm: Double
    let parentBodyId: String?
    let displayOrder: Int
    let textureAssetName: String?
    let thumbnailName: String?
    let hasRings: Bool
    let displaySize: CGFloat

    init(body: CelestialBody) {
        id = body.id
        name = body.name
        typeTitle = body.type.title
        averageDistanceFromSunKm = body.averageDistanceFromSunKm
        averageDistanceFromEarthKm = body.averageDistanceFromEarthKm
        orbitalPeriodDays = body.orbitalPeriodDays
        radiusKm = body.radiusKm
        parentBodyId = body.parentBodyId
        displayOrder = body.displayOrder
        textureAssetName = Self.textureAssetName(for: body.id)
        thumbnailName = body.thumbnailName
        hasRings = body.id == "saturn"
        displaySize = Self.displaySize(for: body)
    }

    var formattedDistance: String {
        if let distance = averageDistanceFromSunKm, distance > 0 {
            return Self.distance(distance)
        }

        if let distance = averageDistanceFromEarthKm, distance > 0 {
            return Self.distance(distance)
        }

        return "nearby"
    }

    var formattedPeriod: String {
        guard let orbitalPeriodDays, orbitalPeriodDays > 0 else {
            return "unknown"
        }

        if orbitalPeriodDays >= 365 {
            return "\(Self.shortNumber(orbitalPeriodDays / 365.25)) years"
        }

        return "\(Self.shortNumber(orbitalPeriodDays)) days"
    }

    func angleRadians(on date: Date) -> Double {
        let days = date.timeIntervalSinceReferenceDate / 86_400
        let baseDegrees = Double(displayOrder * 28)
        let period = max(orbitalPeriodDays ?? 365, 0.1)
        return ((baseDegrees + days / period * 360).truncatingRemainder(dividingBy: 360)) * .pi / 180
    }

    private static func textureAssetName(for id: String) -> String? {
        switch id {
        case "mercury":
            return "WidgetMercury"
        case "venus":
            return "WidgetVenus"
        case "earth":
            return "WidgetEarth"
        case "moon":
            return "WidgetMoon"
        case "mars":
            return "WidgetMars"
        case "jupiter":
            return "WidgetJupiter"
        case "saturn":
            return "WidgetSaturn"
        case "uranus":
            return "WidgetUranus"
        case "neptune":
            return "WidgetNeptune"
        default:
            return nil
        }
    }

    private static func displaySize(for body: CelestialBody) -> CGFloat {
        switch body.id {
        case "mercury":
            return 5
        case "venus", "earth":
            return 7
        case "moon":
            return 4
        case "mars":
            return 6
        case "jupiter":
            return 12
        case "saturn":
            return 11
        case "uranus", "neptune":
            return 9
        default:
            let normalized = max(body.radiusKm, 1) / 69_911
            return max(4, min(12, CGFloat(4 + pow(normalized, 0.42) * 8)))
        }
    }

    private static func distance(_ value: Double) -> String {
        if value >= 1_000_000_000 {
            return "\(shortNumber(value / 1_000_000_000))B km"
        }

        if value >= 1_000_000 {
            return "\(shortNumber(value / 1_000_000))M km"
        }

        return "\(shortNumber(value)) km"
    }

    private static func shortNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value >= 10 ? 1 : 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

enum LunaSaturnRingMetrics {
    static let outerRadiusRatio: CGFloat = 2.33
    static let ellipseHeightRatio: CGFloat = 0.36

    static let bands: [(diameterRatio: CGFloat, opacity: Double, lineWidthRatio: CGFloat)] = [
        (1.24, 0.22, 0.035),
        (1.52, 0.34, 0.040),
        (1.95, 0.28, 0.038),
        (2.27, 0.22, 0.032),
        (outerRadiusRatio, 0.18, 0.025)
    ]
}

enum LunaWidgetThumbnailResourceResolver {
    private final class BundleToken {}

    static func url(named thumbnailName: String?, bundle: Bundle = .main) -> URL? {
        guard let thumbnailName, !thumbnailName.isEmpty else { return nil }

        let resourceName = (thumbnailName as NSString).deletingPathExtension
        let resourceExtension = (thumbnailName as NSString).pathExtension.isEmpty
            ? "png"
            : (thumbnailName as NSString).pathExtension
        let subdirectories = [
            "Thumbnails/NASA",
            "NASA"
        ]

        for candidateBundle in candidateBundles(primary: bundle) {
            for subdirectory in subdirectories {
                if let url = candidateBundle.url(
                    forResource: resourceName,
                    withExtension: resourceExtension,
                    subdirectory: subdirectory
                ) {
                    return url
                }
            }

            if let url = candidateBundle.url(forResource: resourceName, withExtension: resourceExtension) {
                return url
            }
        }

        return nil
    }

    private static func candidateBundles(primary: Bundle) -> [Bundle] {
        let bundles = [
            primary,
            Bundle.main,
            Bundle(for: BundleToken.self)
        ] + Bundle.allBundles + Bundle.allFrameworks
        return bundles.reduce(into: []) { result, bundle in
            guard !result.contains(bundle) else { return }
            result.append(bundle)
        }
    }
}

struct LunaWidgetCatalogLoader {
    var bundle: Bundle = .main
    var resourceName = "celestial_bodies"
    var decoder = JSONDecoder()

    func loadBodies() -> [CelestialBody] {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let bodies = try? decoder.decode([CelestialBody].self, from: data) else {
            return []
        }

        return bodies.sorted { lhs, rhs in
            if lhs.displayOrder == rhs.displayOrder {
                return lhs.id < rhs.id
            }

            return lhs.displayOrder < rhs.displayOrder
        }
    }
}

struct LunaWidgetContentSource {
    var catalogLoader: LunaWidgetCatalogLoader = LunaWidgetCatalogLoader()
    var calendar: Calendar = .current

    func factContent(for date: Date) -> LunaWidgetFactContent {
        let bodies = catalogLoader.loadBodies()
        let provider = HomeDailyContentProvider(calendar: calendar)

        guard let featuredBody = provider.featuredBody(from: bodies, date: date) else {
            return LunaWidgetFactContent(
                date: date,
                body: Self.fallbackBody,
                fact: "The Moon averages 384,400 km from Earth."
            )
        }

        let fact = provider.dailyFact(featuredBody: featuredBody, bodies: bodies, date: date)
        return LunaWidgetFactContent(
            date: date,
            body: LunaWidgetBodySnapshot(body: featuredBody),
            fact: fact.message
        )
    }

    func solarBodies() -> [LunaWidgetBodySnapshot] {
        solarCelestialBodies().map(LunaWidgetBodySnapshot.init(body:))
    }

    func solarCelestialBodies() -> [CelestialBody] {
        catalogLoader.loadBodies()
            .filter { body in
                switch body.type {
                case .star, .planet, .moon, .asteroid, .dwarfPlanet:
                    return true
                case .satellite, .rocket, .spacecraft, .station, .astronaut:
                    return false
                }
            }
    }

    private static var fallbackBody: LunaWidgetBodySnapshot {
        LunaWidgetBodySnapshot(
            body: CelestialBody(
                id: "moon",
                name: "Moon",
                type: .moon,
                subtitle: "",
                summary: "",
                description: "",
                radiusKm: 1_737.4,
                averageDistanceFromSunKm: nil,
                averageDistanceFromEarthKm: 384_400,
                orbitalPeriodDays: 27.32,
                rotationPeriodHours: nil,
                axialTiltDegrees: nil,
                gravity: nil,
                imageName: nil,
                thumbnailName: nil,
                textureName: nil,
                modelName: nil,
                orbit: nil,
                parentBodyId: "earth",
                displayOrder: 4,
                tags: []
            )
        )
    }
}

struct LunaSolarPreviewLayout {
    struct Placement: Identifiable, Equatable {
        let id: String
        let body: CelestialBody
        let bodySize: CGFloat
        let position: CGPoint
    }

    struct Orbit: Identifiable, Equatable {
        let id: String
        let bodyId: String
        let radius: CGFloat
        let points: [CGPoint]
        let isInner: Bool
    }

    let placements: [Placement]
    let orbits: [Orbit]
    let sun: Placement?
    let center: CGPoint
    let sunSize: CGFloat

    init(
        snapshot: ExperienceSceneSnapshot,
        size: CGSize,
        bodySize: (ExperienceSceneBody, CGFloat) -> CGFloat = LunaSolarPreviewLayout.defaultBodySize(for:canvasSize:)
    ) {
        let bounds = snapshot.bounds
        let margin = max(min(size.width, size.height) * 0.08, 14)
        let availableWidth = max(size.width - margin * 2, 1)
        let availableHeight = max(size.height - margin * 2, 1)
        let projectedBounds = Self.projectedBounds(for: snapshot, bounds: bounds)
        let scale = min(
            availableWidth / CGFloat(max(projectedBounds.width, 0.001)),
            availableHeight / CGFloat(max(projectedBounds.height, 0.001))
        )
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        func project(_ point: SIMD3<Float>) -> CGPoint {
            let projectedPoint = Self.expandedProjection(point, bounds: bounds, projectedBounds: projectedBounds)
            return CGPoint(
                x: center.x + CGFloat(projectedPoint.x - projectedBounds.midX) * scale,
                y: center.y + CGFloat(projectedPoint.y - projectedBounds.midY) * scale
            )
        }

        let canvasSize = min(size.width, size.height)
        let bodyPlacements = snapshot.bodies.map { body in
            Placement(
                id: body.id,
                body: body.body,
                bodySize: bodySize(body, canvasSize),
                position: project(body.position)
            )
        }

        placements = bodyPlacements.filter { $0.body.type != .star }
        sun = bodyPlacements.first { $0.body.type == .star }
        self.center = center
        sunSize = sun?.bodySize ?? max(9, min(18, canvasSize * 0.095))
        orbits = snapshot.orbitPaths.map { path in
            let points = path.points.map(project)
            return Orbit(
                id: path.id,
                bodyId: path.bodyId,
                radius: Self.averageRadius(points: points, center: center),
                points: points,
                isInner: Self.innerPlanetIds.contains(path.bodyId)
            )
        }
    }

    static func widgetBodySize(for body: ExperienceSceneBody, canvasSize: CGFloat) -> CGFloat {
        let snapshot = LunaWidgetBodySnapshot(body: body.body)
        return max(snapshot.displaySize, snapshot.hasRings ? 10 : 6)
    }

    static func defaultBodySize(for body: ExperienceSceneBody, canvasSize: CGFloat) -> CGFloat {
        if body.body.type == .star {
            return max(10, min(16, canvasSize * 0.6))
        }

        if body.body.type == .moon {
            return max(5, min(8, canvasSize * 0.035))
        }

        let sourceSize = CGFloat(log10(max(body.body.radiusKm, 1))) * 4.2
        return max(7, min(14, sourceSize))
    }

    private static func averageRadius(points: [CGPoint], center: CGPoint) -> CGFloat {
        guard !points.isEmpty else { return 0 }

        let total = points.reduce(CGFloat.zero) { partialResult, point in
            let x = point.x - center.x
            let y = point.y - center.y
            return partialResult + sqrt(x * x + y * y)
        }
        return total / CGFloat(points.count)
    }

    private static func projectedY(_ point: SIMD3<Float>) -> Float {
        point.z * tiltCosine - point.y * tiltSine
    }

    private static func rawProjection(_ point: SIMD3<Float>, bounds: ExperienceSceneBounds) -> SIMD2<Float> {
        SIMD2<Float>(
            point.x - bounds.center.x,
            projectedY(point) - projectedY(bounds.center)
        )
    }

    private static func expandedProjection(
        _ point: SIMD3<Float>,
        bounds: ExperienceSceneBounds,
        projectedBounds: ProjectedBounds
    ) -> SIMD2<Float> {
        let rawPoint = rawProjection(point, bounds: bounds)
        let radius = max(length(rawPoint), 0.000_001)
        let normalizedRadius = min(max(radius / projectedBounds.rawRadius, 0), 1)
        let expandedRadius = pow(normalizedRadius, 0.72) * projectedBounds.rawRadius
        return rawPoint * (expandedRadius / radius)
    }

    private static func projectedBounds(for snapshot: ExperienceSceneSnapshot, bounds: ExperienceSceneBounds) -> ProjectedBounds {
        let points = snapshot.bodies.map(\.position) + snapshot.orbitPaths.flatMap(\.points)
        let rawPoints = points.map { rawProjection($0, bounds: bounds) }
        let rawRadius = max(rawPoints.map(length).max() ?? 0.001, 0.001)
        let expandedPoints = rawPoints.map { point -> SIMD2<Float> in
            let radius = max(length(point), 0.000_001)
            let normalizedRadius = min(max(radius / rawRadius, 0), 1)
            let expandedRadius = pow(normalizedRadius, 0.72) * rawRadius
            return point * (expandedRadius / radius)
        }

        guard
            let minX = expandedPoints.map(\.x).min(),
            let maxX = expandedPoints.map(\.x).max(),
            let minY = expandedPoints.map(\.y).min(),
            let maxY = expandedPoints.map(\.y).max()
        else {
            return ProjectedBounds(midX: 0, midY: 0, width: 1, height: 1, rawRadius: rawRadius)
        }

        return ProjectedBounds(
            midX: (minX + maxX) / 2,
            midY: (minY + maxY) / 2,
            width: max(maxX - minX, 0.001),
            height: max(maxY - minY, 0.001),
            rawRadius: rawRadius
        )
    }

    private static let tiltAngle = Double.pi * 0.32
    private static let tiltCosine = Float(cos(tiltAngle))
    private static let tiltSine = Float(sin(tiltAngle))
    private static let innerPlanetIds: Set<String> = ["mercury", "venus", "earth", "mars"]

    private struct ProjectedBounds {
        let midX: Float
        let midY: Float
        let width: Float
        let height: Float
        let rawRadius: Float
    }
}
