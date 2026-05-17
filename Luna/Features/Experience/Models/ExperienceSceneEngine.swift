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

private struct ExperienceSceneScaleContext {
    let displayRadii: [String: Float]
    let sunOrbitRadii: [String: Float]
    let childOrbitRadii: [String: Float]
    let maxSunDistance: Double
}

protocol ExperienceSceneRenderer {
    associatedtype RenderTarget

    func apply(snapshot: ExperienceSceneSnapshot, to target: RenderTarget)
}

enum ExperienceSceneEngine {
    private static let trueDistanceKilometersPerSceneUnit: Double = 316_553_521
    private static let compressedDistanceKilometersPerSceneUnit: Double = 74_900_000
    private static let trueRadiusKilometersPerSceneUnit: Double = 129_465
    private static let trueRadiusVisualFloor: Float = 0.004

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
        let displayRadii = Dictionary(
            uniqueKeysWithValues: sortedBodies.map { body in
                (body.id, displayRadius(for: body, settings: settings, content: content))
            }
        )
        let scaleContext = scaleContext(
            for: sortedBodies,
            displayRadii: displayRadii,
            maxSunDistance: maxSunDistance,
            settings: settings
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
                scaleContext: scaleContext,
                simulationTimeDays: simulationTimeDays
            )
            let radius = displayRadii[body.id] ?? displayRadius(for: body, settings: settings, content: content)
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
            ? orbitPaths(
                for: sortedBodies,
                parentPositions: parentPositions,
                settings: settings,
                content: content,
                scaleContext: scaleContext
            )
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
        scaleContext: ExperienceSceneScaleContext,
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
            return parentPosition + childOffset(
                for: body,
                settings: settings,
                scaleContext: scaleContext,
                simulationTimeDays: simulationTimeDays
            )
        }

        let distance = scaleContext.sunOrbitRadii[body.id]
            ?? baseSunDistance(for: body, maxSunDistance: scaleContext.maxSunDistance, settings: settings)
        let angle = orbitalAngle(for: body, simulationTimeDays: simulationTimeDays)

        if settings.distanceScaleMode == .trueScale {
            return orbitOffset(
                for: body,
                radius: distance,
                angle: angle,
                isTrueScale: true
            )
        }

        return SIMD3<Float>(
            cos(angle) * distance,
            orbitYOffset(for: body),
            sin(angle) * distance
        )
    }

    private static func childOffset(
        for body: CelestialBody,
        settings: ExperienceSceneSettings,
        scaleContext: ExperienceSceneScaleContext,
        simulationTimeDays: Double
    ) -> SIMD3<Float> {
        let angle = orbitalAngle(for: body, simulationTimeDays: simulationTimeDays)
        let radius = scaleContext.childOrbitRadii[body.id] ?? baseChildOrbitRadius(for: body, settings: settings)

        return orbitOffset(
            for: body,
            radius: radius,
            angle: angle,
            isTrueScale: settings.distanceScaleMode == .trueScale
        )
    }

    private static func displayRadius(
        for body: CelestialBody,
        settings: ExperienceSceneSettings,
        content: ExperienceSceneContent
    ) -> Float {
        let radius = objectModeRadius(for: body, settings: settings)

        if case .object = content {
            return radius * 1.45
        }

        return radius * trueDistanceVisualScale(for: body, settings: settings)
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
            case .moon:
                let normalized = Float(max(body.radiusKm, 1) / 69_911)
                return min(0.16, max(0.13, 0.11 + pow(normalized, 0.42) * 0.34))
            default:
                let normalized = Float(max(body.radiusKm, 1) / 69_911)
                return min(0.42, max(0.13, 0.11 + pow(normalized, 0.42) * 0.34))
            }
        case .trueScale:
            switch body.type {
            default:
                // Interaction still needs a tiny renderable target, but true-size ratios are
                // otherwise a single fixed kilometer-to-scene-unit conversion.
                return max(trueRadiusVisualFloor, Float(body.radiusKm / trueRadiusKilometersPerSceneUnit))
            }
        }
    }

    private static func orbitPaths(
        for bodies: [CelestialBody],
        parentPositions: [String: SIMD3<Float>],
        settings: ExperienceSceneSettings,
        content: ExperienceSceneContent,
        scaleContext: ExperienceSceneScaleContext
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
                settings: settings,
                scaleContext: scaleContext
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
        settings: ExperienceSceneSettings,
        scaleContext: ExperienceSceneScaleContext
    ) -> [SIMD3<Float>] {
        let radius: Float

        if body.parentBodyId == "sun" {
            radius = scaleContext.sunOrbitRadii[body.id]
                ?? baseSunDistance(for: body, maxSunDistance: scaleContext.maxSunDistance, settings: settings)
        } else {
            radius = scaleContext.childOrbitRadii[body.id] ?? baseChildOrbitRadius(for: body, settings: settings)
        }

        let eccentricity = Float(body.orbit?.eccentricity ?? 0)
        let inclination = Float((body.orbit?.inclinationDegrees ?? 0) * .pi / 180)
        let isTrueScale = settings.distanceScaleMode == .trueScale

        return (0..<128).map { index in
            let angle = Float(index) / 128 * Float.pi * 2
            let semiMinor = radius * sqrt(max(0.1, 1 - eccentricity * eccentricity))
            let x = cos(angle) * radius
            let z = sin(angle) * semiMinor
            let y = z * sin(inclination) * (isTrueScale ? 1 : 0.18)
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

    private static func scaleContext(
        for bodies: [CelestialBody],
        displayRadii: [String: Float],
        maxSunDistance: Double,
        settings: ExperienceSceneSettings
    ) -> ExperienceSceneScaleContext {
        let childOrbitRadii = childOrbitRadii(
            for: bodies,
            displayRadii: displayRadii,
            settings: settings
        )
        let sunOrbitRadii = sunOrbitRadii(
            for: bodies,
            displayRadii: displayRadii,
            childOrbitRadii: childOrbitRadii,
            maxSunDistance: maxSunDistance,
            settings: settings
        )

        return ExperienceSceneScaleContext(
            displayRadii: displayRadii,
            sunOrbitRadii: sunOrbitRadii,
            childOrbitRadii: childOrbitRadii,
            maxSunDistance: maxSunDistance
        )
    }

    private static func childOrbitRadii(
        for bodies: [CelestialBody],
        displayRadii: [String: Float],
        settings: ExperienceSceneSettings
    ) -> [String: Float] {
        Dictionary(
            uniqueKeysWithValues: bodies.compactMap { body in
                guard let parentId = body.parentBodyId,
                      parentId != "sun" else {
                    return nil
                }

                let baseRadius = baseChildOrbitRadius(for: body, settings: settings)
                let parentRadius = displayRadii[parentId] ?? 0
                let bodyRadius = displayRadii[body.id] ?? 0
                let minimumRadius = parentRadius + bodyRadius + childOrbitClearanceMargin(for: settings)
                return (body.id, max(baseRadius, minimumRadius))
            }
        )
    }

    private static func sunOrbitRadii(
        for bodies: [CelestialBody],
        displayRadii: [String: Float],
        childOrbitRadii: [String: Float],
        maxSunDistance: Double,
        settings: ExperienceSceneSettings
    ) -> [String: Float] {
        let sunChildren = bodies
            .filter { $0.parentBodyId == "sun" && $0.type != .star }
            .sorted { $0.displayOrder < $1.displayOrder }
        guard !sunChildren.isEmpty else { return [:] }

        let multiplier = settings.distanceScaleMode == .trueScale
            ? trueDistancePlanetMultiplier(
                for: sunChildren,
                bodies: bodies,
                displayRadii: displayRadii,
                childOrbitRadii: childOrbitRadii,
                maxSunDistance: maxSunDistance,
                settings: settings
            )
            : 1

        var result: [String: Float] = [:]
        var previousRadius: Float?
        var previousEnvelope: Float = 0

        for (index, body) in sunChildren.enumerated() {
            var radius = baseSunDistance(
                for: body,
                index: index,
                maxSunDistance: maxSunDistance,
                settings: settings
            ) * multiplier
            let envelope = systemEnvelopeRadius(
                for: body,
                bodies: bodies,
                displayRadii: displayRadii,
                childOrbitRadii: childOrbitRadii
            )
            let sunRadius = displayRadii["sun"] ?? 0
            let minimumFromSun = sunRadius + envelope + sunOrbitClearanceMargin(for: settings)

            if settings.distanceScaleMode != .trueScale {
                radius = max(radius, minimumFromSun)

                if let previousRadius {
                    radius = max(radius, previousRadius + previousEnvelope + envelope + interOrbitClearanceMargin(for: settings))
                }
            }

            result[body.id] = radius
            previousRadius = radius
            previousEnvelope = envelope
        }

        return result
    }

    private static func trueDistancePlanetMultiplier(
        for sunChildren: [CelestialBody],
        bodies: [CelestialBody],
        displayRadii: [String: Float],
        childOrbitRadii: [String: Float],
        maxSunDistance: Double,
        settings: ExperienceSceneSettings
    ) -> Float {
        let sunRadius = displayRadii["sun"] ?? 0
        var multiplier = Float(1)

        for body in sunChildren {
            let baseRadius = baseSunDistance(for: body, maxSunDistance: maxSunDistance, settings: settings)
            guard baseRadius > 0 else { continue }

            let envelope = systemEnvelopeRadius(
                for: body,
                bodies: bodies,
                displayRadii: displayRadii,
                childOrbitRadii: childOrbitRadii
            )
            let requiredRadius = sunRadius + envelope + sunOrbitClearanceMargin(for: settings)
            multiplier = max(multiplier, requiredRadius / baseRadius)
        }

        for pair in zip(sunChildren, sunChildren.dropFirst()) {
            let inner = pair.0
            let outer = pair.1
            let innerRadius = baseSunDistance(for: inner, maxSunDistance: maxSunDistance, settings: settings)
            let outerRadius = baseSunDistance(for: outer, maxSunDistance: maxSunDistance, settings: settings)
            let baseGap = outerRadius - innerRadius
            guard baseGap > 0 else { continue }

            let requiredGap = systemEnvelopeRadius(
                for: inner,
                bodies: bodies,
                displayRadii: displayRadii,
                childOrbitRadii: childOrbitRadii
            ) + systemEnvelopeRadius(
                for: outer,
                bodies: bodies,
                displayRadii: displayRadii,
                childOrbitRadii: childOrbitRadii
            ) + interOrbitClearanceMargin(for: settings)

            multiplier = max(multiplier, requiredGap / baseGap)
        }

        return multiplier
    }

    private static func systemEnvelopeRadius(
        for body: CelestialBody,
        bodies: [CelestialBody],
        displayRadii: [String: Float],
        childOrbitRadii: [String: Float]
    ) -> Float {
        let bodyRadius = displayRadii[body.id] ?? 0
        let childEnvelope = bodies
            .filter { $0.parentBodyId == body.id }
            .map { child in
                (childOrbitRadii[child.id] ?? 0) + (displayRadii[child.id] ?? 0)
            }
            .max() ?? 0

        return max(bodyRadius, childEnvelope)
    }

    private static func baseSunDistance(
        for body: CelestialBody,
        index: Int? = nil,
        maxSunDistance: Double,
        settings: ExperienceSceneSettings
    ) -> Float {
        switch settings.distanceScaleMode {
        case .educational:
            return Float((index ?? max(body.displayOrder - 1, 0)) + 1) * 1.18
        case .compressed:
            let compression = Float(ExperienceSceneSettings.clampedDistanceCompression(settings.distanceCompression))
            return compressedDistance(for: body, fallbackDistance: body.averageDistanceFromSunKm) / compression
        case .trueScale:
            return trueDistance(for: body, fallbackDistance: body.averageDistanceFromSunKm)
        }
    }

    private static func baseChildOrbitRadius(for body: CelestialBody, settings: ExperienceSceneSettings) -> Float {
        if body.id == "moon" {
            switch settings.distanceScaleMode {
            case .educational:
                return 0.44
            case .compressed:
                let compression = Float(ExperienceSceneSettings.clampedDistanceCompression(settings.distanceCompression))
                return compressedDistance(for: body, fallbackDistance: body.averageDistanceFromEarthKm) / compression
            case .trueScale:
                return trueDistance(for: body, fallbackDistance: body.averageDistanceFromEarthKm)
            }
        }

        switch settings.distanceScaleMode {
        case .trueScale:
            return trueDistance(for: body, fallbackDistance: body.averageDistanceFromEarthKm)
        case .compressed:
            let compression = Float(ExperienceSceneSettings.clampedDistanceCompression(settings.distanceCompression))
            return compressedDistance(for: body, fallbackDistance: body.averageDistanceFromEarthKm) / compression
        default:
            return 0.42
        }
    }

    private static func sunOrbitClearanceMargin(for settings: ExperienceSceneSettings) -> Float {
        switch settings.distanceScaleMode {
        case .educational:
            return settings.objectScaleMode == .trueScale ? 0.55 : 0.08
        case .compressed:
            return settings.objectScaleMode == .trueScale ? 0.32 : 0.12
        case .trueScale:
            return settings.objectScaleMode == .trueScale ? 0.42 : 0.16
        }
    }

    private static func childOrbitClearanceMargin(for settings: ExperienceSceneSettings) -> Float {
        switch settings.distanceScaleMode {
        case .educational:
            return 0.05
        case .compressed:
            return 0.08
        case .trueScale:
            return 0.10
        }
    }

    private static func interOrbitClearanceMargin(for settings: ExperienceSceneSettings) -> Float {
        settings.distanceScaleMode == .compressed ? 0.12 : 0.08
    }

    private static func trueDistanceVisualScale(for body: CelestialBody, settings: ExperienceSceneSettings) -> Float {
        guard settings.distanceScaleMode == .trueScale,
              settings.objectScaleMode != .trueScale else {
            return 1
        }

        switch settings.objectScaleMode {
        case .uniform:
            switch body.type {
            case .star:
                return 0.88
            case .moon:
                return 0.55
            default:
                return 0.74
            }
        case .relative:
            switch body.type {
            case .star:
                return 0.92
            case .moon:
                return 0.68
            default:
                return 0.86
            }
        case .trueScale:
            return 1
        }
    }

    private static func orbitOffset(
        for body: CelestialBody,
        radius: Float,
        angle: Float,
        isTrueScale: Bool
    ) -> SIMD3<Float> {
        let eccentricity = Float(body.orbit?.eccentricity ?? 0)
        let inclination = Float((body.orbit?.inclinationDegrees ?? 0) * .pi / 180)
        let semiMinor = radius * sqrt(max(0.1, 1 - eccentricity * eccentricity))
        let x = cos(angle) * radius
        let z = sin(angle) * semiMinor
        let y = z * sin(inclination) * (isTrueScale ? 1 : 0.18)
        return SIMD3<Float>(x, y, z * cos(inclination))
    }

    private static func trueDistance(for body: CelestialBody, fallbackDistance: Double?) -> Float {
        let distance = body.orbit?.semiMajorAxisKm ?? fallbackDistance ?? 0
        return Float(max(distance, 0) / trueDistanceKilometersPerSceneUnit)
    }

    private static func compressedDistance(for body: CelestialBody, fallbackDistance: Double?) -> Float {
        let distance = body.orbit?.semiMajorAxisKm ?? fallbackDistance ?? 0
        return Float(max(distance, 0) / compressedDistanceKilometersPerSceneUnit)
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
