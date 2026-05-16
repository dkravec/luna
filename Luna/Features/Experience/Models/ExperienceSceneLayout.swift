import Foundation
import simd

struct SceneBodyPlacement: Identifiable, Equatable {
    var id: String { body.id }

    let body: CelestialBody
    let position: SIMD3<Float>
    let displayRadius: Float
    let orbitRadius: Float?
}

enum ExperienceSceneLayout {
    static func placements(
        for bodies: [CelestialBody],
        settings: SolarSystemSceneSettings
    ) -> [SceneBodyPlacement] {
        let sortedBodies = bodies.sorted { $0.displayOrder < $1.displayOrder }
        let sunDistances = sortedBodies
            .compactMap(\.averageDistanceFromSunKm)
            .filter { $0 > 0 }
        let maxSunDistance = max(sunDistances.max() ?? 1, 1)

        var parentPositions: [String: SIMD3<Float>] = [:]
        var placements: [SceneBodyPlacement] = []

        for body in sortedBodies {
            let position = position(
                for: body,
                bodies: sortedBodies,
                parentPositions: parentPositions,
                settings: settings,
                maxSunDistance: maxSunDistance
            )

            let placement = SceneBodyPlacement(
                body: body,
                position: position,
                displayRadius: displayRadius(for: body, settings: settings),
                orbitRadius: orbitRadius(for: body, position: position, settings: settings)
            )

            placements.append(placement)
            parentPositions[body.id] = position
        }

        return placements
    }

    private static func position(
        for body: CelestialBody,
        bodies: [CelestialBody],
        parentPositions: [String: SIMD3<Float>],
        settings: SolarSystemSceneSettings,
        maxSunDistance: Double
    ) -> SIMD3<Float> {
        if body.type == .star {
            return .zero
        }

        if let parentId = body.parentBodyId,
           parentId != "sun",
           let parentPosition = parentPositions[parentId] {
            let siblings = bodies.filter { $0.parentBodyId == parentId }
            let siblingIndex = siblings.firstIndex { $0.id == body.id } ?? 0
            let orbitRadius = childOrbitRadius(
                for: body,
                siblings: siblings,
                settings: settings
            )
            let angle = (Float(siblingIndex) / Float(max(siblings.count, 1))) * (Float.pi * 2)
                + Float.pi / 8
            let vertical = siblingIndex.isMultiple(of: 2) ? Float(0.08) : Float(-0.08)

            return parentPosition + SIMD3<Float>(
                cos(angle) * orbitRadius,
                vertical,
                sin(angle) * orbitRadius
            )
        }

        let sunOrder = bodies
            .filter { $0.parentBodyId == nil || $0.parentBodyId == "sun" }
            .filter { $0.type != .star }
            .sorted { $0.displayOrder < $1.displayOrder }
        let orderIndex = sunOrder.firstIndex { $0.id == body.id } ?? 0
        let xPosition: Float

        switch settings.scaleMode {
        case .educational, .custom:
            xPosition = Float(orderIndex + 1) * 1.55 * spacingMultiplier(for: settings)
        case .compressedDistance:
            let normalized = normalizedSunDistance(for: body, maxSunDistance: maxSunDistance)
            let compression = Float(max(settings.distanceCompression, 5))
            let range = max(5.8, 14 - (compression / 10))
            xPosition = (1.2 + pow(Float(normalized), 0.42) * range) * spacingMultiplier(for: settings)
        case .trueDistance:
            let normalized = normalizedSunDistance(for: body, maxSunDistance: maxSunDistance)
            xPosition = (1.2 + pow(Float(normalized), 0.82) * 13.5) * spacingMultiplier(for: settings)
        }

        return SIMD3<Float>(xPosition, 0, 0)
    }

    private static func orbitRadius(
        for body: CelestialBody,
        position: SIMD3<Float>,
        settings: SolarSystemSceneSettings
    ) -> Float? {
        guard settings.showOrbits,
              body.parentBodyId == nil || body.parentBodyId == "sun",
              body.type != .star else {
            return nil
        }

        return abs(position.x)
    }

    private static func displayRadius(
        for body: CelestialBody,
        settings: SolarSystemSceneSettings
    ) -> Float {
        let multiplier = Float(settings.planetSizeMultiplier)

        switch body.type {
        case .star:
            return min(0.78, 0.50 * pow(multiplier, 0.12))
        case .satellite:
            return min(0.10, 0.010 * pow(multiplier, 0.58))
        case .moon, .asteroid, .dwarfPlanet:
            let baseRadius = max(0.012, min(0.16, Float(body.radiusKm / 69_911) * 0.42))
            return min(0.28, baseRadius * pow(multiplier, 0.58))
        case .planet:
            let baseRadius = max(0.016, min(0.42, Float(body.radiusKm / 69_911) * 0.42))
            return min(0.72, baseRadius * pow(multiplier, 0.58))
        }
    }

    private static func childOrbitRadius(
        for body: CelestialBody,
        siblings: [CelestialBody],
        settings: SolarSystemSceneSettings
    ) -> Float {
        let siblingDistances = siblings
            .compactMap(\.averageDistanceFromEarthKm)
            .filter { $0 > 0 }
        let maxSiblingDistance = max(siblingDistances.max() ?? 384_400, 384_400)
        let distance = max(body.averageDistanceFromEarthKm ?? maxSiblingDistance, 1)
        let normalizedDistance = Float(min(max(distance / maxSiblingDistance, 0), 1))
        let baseRadius = 0.28 + pow(normalizedDistance, 0.48) * 1.02

        return baseRadius * spacingMultiplier(for: settings)
    }

    private static func spacingMultiplier(for settings: SolarSystemSceneSettings) -> Float {
        let multiplier = Float(max(settings.planetSizeMultiplier, 1))
        return 1 + (sqrt(multiplier) - 1) * 0.22
    }

    private static func normalizedSunDistance(for body: CelestialBody, maxSunDistance: Double) -> Double {
        guard let distance = body.averageDistanceFromSunKm, distance > 0 else {
            return 0
        }

        return min(max(distance / maxSunDistance, 0), 1)
    }
}
