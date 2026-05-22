import CoreGraphics
import Foundation

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
        catalogLoader.loadBodies()
            .filter { body in
                body.parentBodyId == "sun" && body.type == .planet
            }
            .map(LunaWidgetBodySnapshot.init(body:))
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

struct LunaWidgetSolarLayoutModel {
    struct Orbit: Identifiable, Equatable {
        let id: String
        let radius: CGFloat
        let points: [CGPoint]
        let isInner: Bool
    }

    struct Placement: Identifiable, Equatable {
        let id: String
        let body: LunaWidgetBodySnapshot
        let position: CGPoint
        let size: CGFloat
        let radius: CGFloat
    }

    let center: CGPoint
    let sunSize: CGFloat
    let orbits: [Orbit]
    let placements: [Placement]

    init(bodies: [LunaWidgetBodySnapshot], size: CGSize, date: Date) {
        let canvas = max(min(size.width, size.height), 1)
        let maxBodySize = max(bodies.map { max($0.displaySize, $0.hasRings ? 10 : 6) }.max() ?? 10, 10)
        let centerPoint = CGPoint(x: size.width / 2, y: size.height / 2)
        let computedSunSize = max(9, min(18, canvas * 0.095))
        let margin = max(canvas * 0.06, 6) + maxBodySize / 2
        let minRadius = computedSunSize / 2 + max(canvas * 0.055, 6)
        let maxRadius = max(min(size.width, size.height) / 2 - margin, minRadius + 1)
        let solarBodies = bodies
            .filter { ($0.averageDistanceFromSunKm ?? 0) > 0 }
            .sorted { lhs, rhs in
                if lhs.displayOrder == rhs.displayOrder {
                    return lhs.id < rhs.id
                }

                return lhs.displayOrder < rhs.displayOrder
            }
        let maxEducationalIndex = max(CGFloat(max(solarBodies.count - 1, 1)), 1)

        func radius(for index: Int) -> CGFloat {
            let normalized = CGFloat(index) / maxEducationalIndex
            return minRadius + normalized * (maxRadius - minRadius)
        }

        func project(radius: CGFloat, angle: Double) -> CGPoint {
            CGPoint(
                x: centerPoint.x + cos(angle) * radius,
                y: centerPoint.y + sin(angle) * radius * Self.tiltScale
            )
        }

        let computedOrbits = solarBodies.enumerated().map { index, body in
            let radius = radius(for: index)
            let points = stride(from: 0, to: Self.pathSegments, by: 1).map { pointIndex in
                project(
                    radius: radius,
                    angle: Double(pointIndex) / Double(Self.pathSegments) * .pi * 2
                )
            }
            return Orbit(id: body.id, radius: radius, points: points, isInner: index <= 3)
        }

        let computedPlacements = solarBodies.enumerated().map { index, body in
            let radius = radius(for: index)
            return Placement(
                id: body.id,
                body: body,
                position: project(radius: radius, angle: body.angleRadians(on: date)),
                size: max(body.displaySize, body.hasRings ? 10 : 6),
                radius: radius
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
