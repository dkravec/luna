import Foundation
import simd

enum ExperienceSceneContent: Equatable {
    case solarSystem
    case object(String)
}

struct ExperienceSceneSnapshot: Equatable {
    let bodies: [ExperienceSceneBody]
    let orbitPaths: [ExperienceOrbitPath]
    let bounds: ExperienceSceneBounds
}

struct ExperienceSceneBody: Identifiable, Equatable {
    var id: String { body.id }

    let body: CelestialBody
    let position: SIMD3<Float>
    let displayRadius: Float
    let labelPosition: SIMD3<Float>
    let rotationAngleRadians: Float
    let axialTiltRadians: Float
}

struct ExperienceOrbitPath: Identifiable, Equatable {
    let id: String
    let bodyId: String
    let parentBodyId: String
    let points: [SIMD3<Float>]
}

struct ExperienceSceneBounds: Equatable {
    static let empty = ExperienceSceneBounds(center: .zero, size: SIMD3<Float>(repeating: 1), span: 1)

    let center: SIMD3<Float>
    let size: SIMD3<Float>
    let span: Float

    init(bodies: [ExperienceSceneBody]) {
        guard !bodies.isEmpty else {
            self = .empty
            return
        }

        let minX = bodies.map { $0.position.x - $0.displayRadius }.min() ?? -0.5
        let maxX = bodies.map { $0.position.x + $0.displayRadius }.max() ?? 0.5
        let minY = bodies.map { $0.position.y - $0.displayRadius }.min() ?? -0.5
        let maxY = bodies.map { $0.position.y + $0.displayRadius }.max() ?? 0.5
        let minZ = bodies.map { $0.position.z - $0.displayRadius }.min() ?? -0.5
        let maxZ = bodies.map { $0.position.z + $0.displayRadius }.max() ?? 0.5

        center = SIMD3<Float>(
            (minX + maxX) / 2,
            (minY + maxY) / 2,
            (minZ + maxZ) / 2
        )
        size = SIMD3<Float>(
            max(0.1, maxX - minX),
            max(0.1, maxY - minY),
            max(0.1, maxZ - minZ)
        )
        span = max(size.x, max(size.y, size.z))
    }

    private init(center: SIMD3<Float>, size: SIMD3<Float>, span: Float) {
        self.center = center
        self.size = size
        self.span = span
    }
}

protocol ExperienceSceneRenderer {
    associatedtype RenderTarget

    func apply(snapshot: ExperienceSceneSnapshot, to target: RenderTarget)
}

enum ExperienceSceneEngine {
    static func snapshot(
        for bodies: [CelestialBody],
        settings: ExperienceSceneSettings,
        content: ExperienceSceneContent = .solarSystem,
        simulationTimeDays: Double = 0
    ) -> ExperienceSceneSnapshot {
        let filteredBodies = bodiesForContent(bodies, content: content)
        let sortedBodies = filteredBodies.sorted { $0.displayOrder < $1.displayOrder }
        let maxSunDistance = max(
            sortedBodies.compactMap(\.averageDistanceFromSunKm).filter { $0 > 0 }.max() ?? 1,
            1
        )

        var parentPositions: [String: SIMD3<Float>] = [:]
        var sceneBodies: [ExperienceSceneBody] = []

        for body in sortedBodies {
            let position = position(
                for: body,
                bodies: sortedBodies,
                parentPositions: parentPositions,
                settings: settings,
                content: content,
                maxSunDistance: maxSunDistance,
                simulationTimeDays: simulationTimeDays
            )
            let radius = displayRadius(for: body, settings: settings, content: content)
            let sceneBody = ExperienceSceneBody(
                body: body,
                position: position,
                displayRadius: radius,
                labelPosition: position + SIMD3<Float>(0, radius + max(0.28, radius * 0.58), 0),
                rotationAngleRadians: rotationAngleRadians(
                    for: body,
                    simulationTimeDays: simulationTimeDays,
                    speed: settings.objectRotationSpeed
                ),
                axialTiltRadians: axialTiltRadians(for: body)
            )

            sceneBodies.append(sceneBody)
            parentPositions[body.id] = position
        }

        let orbitPaths = settings.showOrbits
            ? orbitPaths(for: sortedBodies, parentPositions: parentPositions, settings: settings, content: content)
            : []

        return ExperienceSceneSnapshot(
            bodies: sceneBodies,
            orbitPaths: orbitPaths,
            bounds: ExperienceSceneBounds(bodies: sceneBodies)
        )
    }

    private static func bodiesForContent(_ bodies: [CelestialBody], content: ExperienceSceneContent) -> [CelestialBody] {
        switch content {
        case .solarSystem:
            return bodies.filter { body in
                body.type != .satellite
            }
        case .object(let bodyId):
            return bodies.filter { $0.id == bodyId }
        }
    }

    private static func position(
        for body: CelestialBody,
        bodies: [CelestialBody],
        parentPositions: [String: SIMD3<Float>],
        settings: ExperienceSceneSettings,
        content: ExperienceSceneContent,
        maxSunDistance: Double,
        simulationTimeDays: Double
    ) -> SIMD3<Float> {
        if case .object = content {
            return .zero
        }

        if body.type == .star {
            return .zero
        }

        if let parentId = body.parentBodyId,
           parentId != "sun",
           let parentPosition = parentPositions[parentId] {
            return parentPosition + childOffset(for: body, settings: settings, simulationTimeDays: simulationTimeDays)
        }

        let sunChildren = bodies
            .filter { $0.parentBodyId == "sun" && $0.type != .star }
            .sorted { $0.displayOrder < $1.displayOrder }
        let index = sunChildren.firstIndex { $0.id == body.id } ?? 0
        let distance = sunDistance(for: body, index: index, maxSunDistance: maxSunDistance, settings: settings)
        let angle = orbitalAngle(for: body, simulationTimeDays: simulationTimeDays)

        return SIMD3<Float>(
            cos(angle) * distance,
            orbitYOffset(for: body),
            sin(angle) * distance
        )
    }

    private static func sunDistance(
        for body: CelestialBody,
        index: Int,
        maxSunDistance: Double,
        settings: ExperienceSceneSettings
    ) -> Float {
        switch settings.distanceScaleMode {
        case .educational:
            return Float(index + 1) * 1.18
        case .compressed:
            let normalized = Float(normalizedSunDistance(for: body, maxSunDistance: maxSunDistance))
            let compression = Float(max(settings.distanceCompression, 5))
            let range = max(4.2, 10.4 - compression * 0.045)
            return 0.9 + pow(normalized, 0.44) * range
        case .trueScale:
            let normalized = Float(normalizedSunDistance(for: body, maxSunDistance: maxSunDistance))
            return 1.0 + pow(normalized, 0.82) * 13.2
        }
    }

    private static func childOffset(
        for body: CelestialBody,
        settings: ExperienceSceneSettings,
        simulationTimeDays: Double
    ) -> SIMD3<Float> {
        let angle = orbitalAngle(for: body, simulationTimeDays: simulationTimeDays)
        let radius: Float

        if body.id == "moon" {
            switch settings.distanceScaleMode {
            case .educational:
                radius = 0.44
            case .compressed:
                radius = 0.54
            case .trueScale:
                radius = 0.72
            }
        } else {
            radius = 0.42
        }

        return SIMD3<Float>(cos(angle) * radius, 0.06, sin(angle) * radius)
    }

    private static func displayRadius(
        for body: CelestialBody,
        settings: ExperienceSceneSettings,
        content: ExperienceSceneContent
    ) -> Float {
        if case .object = content {
            return objectModeRadius(for: body, settings: settings) * 1.45
        }

        return objectModeRadius(for: body, settings: settings)
    }

    private static func objectModeRadius(for body: CelestialBody, settings: ExperienceSceneSettings) -> Float {
        switch settings.objectScaleMode {
        case .uniform:
            switch body.type {
            case .star:
                return 0.34
            case .moon, .dwarfPlanet, .asteroid:
                return 0.18
            case .satellite:
                return 0.09
            case .planet:
                return 0.20
            }
        case .relative:
            switch body.type {
            case .star:
                return 0.46
            case .satellite:
                return 0.08
            default:
                let normalized = Float(max(body.radiusKm, 1) / 69_911)
                return min(0.42, max(0.13, 0.11 + pow(normalized, 0.42) * 0.34))
            }
        case .trueScale:
            switch body.type {
            case .star:
                return 0.58
            case .satellite:
                return 0.045
            default:
                let normalized = Float(max(body.radiusKm, 1) / 69_911)
                return min(0.54, max(0.045, pow(normalized, 0.74) * 0.54))
            }
        }
    }

    private static func orbitPaths(
        for bodies: [CelestialBody],
        parentPositions: [String: SIMD3<Float>],
        settings: ExperienceSceneSettings,
        content: ExperienceSceneContent
    ) -> [ExperienceOrbitPath] {
        guard content == .solarSystem else { return [] }

        return bodies.compactMap { body in
            guard body.type != .star,
                  let parentId = body.parentBodyId,
                  let parentPosition = parentPositions[parentId] else {
                return nil
            }

            let points = orbitPoints(
                for: body,
                parentPosition: parentPosition,
                bodies: bodies,
                settings: settings
            )

            guard points.count > 2 else { return nil }

            return ExperienceOrbitPath(
                id: "\(body.id)-orbit",
                bodyId: body.id,
                parentBodyId: parentId,
                points: points
            )
        }
    }

    private static func orbitPoints(
        for body: CelestialBody,
        parentPosition: SIMD3<Float>,
        bodies: [CelestialBody],
        settings: ExperienceSceneSettings
    ) -> [SIMD3<Float>] {
        let radius: Float

        if body.parentBodyId == "sun" {
            let maxSunDistance = max(bodies.compactMap(\.averageDistanceFromSunKm).filter { $0 > 0 }.max() ?? 1, 1)
            let index = bodies
                .filter { $0.parentBodyId == "sun" && $0.type != .star }
                .sorted { $0.displayOrder < $1.displayOrder }
                .firstIndex { $0.id == body.id } ?? 0
            radius = sunDistance(for: body, index: index, maxSunDistance: maxSunDistance, settings: settings)
        } else {
            radius = body.id == "moon" ? childOffset(for: body, settings: settings, simulationTimeDays: 0).xzLength : 0.42
        }

        let eccentricity = Float(body.orbit?.eccentricity ?? 0)
        let inclination = Float((body.orbit?.inclinationDegrees ?? 0) * .pi / 180)

        return (0..<128).map { index in
            let angle = Float(index) / 128 * Float.pi * 2
            let semiMinor = radius * sqrt(max(0.1, 1 - eccentricity * eccentricity))
            let x = cos(angle) * radius
            let z = sin(angle) * semiMinor
            let y = z * sin(inclination) * 0.18
            return parentPosition + SIMD3<Float>(x, y, z * cos(inclination))
        }
    }

    private static func orbitalAngle(for body: CelestialBody, simulationTimeDays: Double) -> Float {
        let baseDegrees = body.orbit?.meanAnomalyAtEpochDegrees ?? Double(body.displayOrder * 28)
        let period = max(body.orbitalPeriodDays ?? 365, 0.1)
        let degrees = baseDegrees + simulationTimeDays / period * 360
        return Float(degrees.truncatingRemainder(dividingBy: 360) * .pi / 180)
    }

    static func rotationAngleRadians(
        for body: CelestialBody,
        simulationTimeDays: Double,
        speed: ObjectRotationSpeed = .standard
    ) -> Float {
        guard let rotationPeriodHours = body.rotationPeriodHours,
              rotationPeriodHours != 0 else {
            return 0
        }

        let rotationDays = abs(rotationPeriodHours) / 24
        let direction = rotationPeriodHours < 0 ? -1.0 : 1.0
        let rotations = simulationTimeDays / max(rotationDays, 0.001) * speed.multiplier
        let radians = rotations.truncatingRemainder(dividingBy: 1) * .pi * 2 * direction
        return Float(radians)
    }

    static func axialTiltRadians(for body: CelestialBody) -> Float {
        Float((body.axialTiltDegrees ?? defaultAxialTiltDegrees(for: body)) * .pi / 180)
    }

    private static func orbitYOffset(for body: CelestialBody) -> Float {
        Float((body.orbit?.inclinationDegrees ?? 0) / 180) * 0.10
    }

    private static func normalizedSunDistance(for body: CelestialBody, maxSunDistance: Double) -> Double {
        guard let distance = body.averageDistanceFromSunKm, distance > 0 else {
            return 0
        }

        return min(max(distance / maxSunDistance, 0), 1)
    }

    private static func defaultAxialTiltDegrees(for body: CelestialBody) -> Double {
        switch body.id {
        case "sun":
            return 7.25
        case "mercury":
            return 0.034
        case "venus":
            return 177.36
        case "earth":
            return 23.44
        case "moon":
            return 6.68
        case "mars":
            return 25.19
        case "jupiter":
            return 3.13
        case "saturn":
            return 26.73
        case "uranus":
            return 97.77
        case "neptune":
            return 28.32
        default:
            return 0
        }
    }
}

private extension SIMD3<Float> {
    var xzLength: Float {
        sqrt(x * x + z * z)
    }
}
