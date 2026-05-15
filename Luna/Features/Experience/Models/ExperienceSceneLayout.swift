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
                orbitRadius: orbitRadius(for: body, settings: settings, maxSunDistance: maxSunDistance)
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
            let offset = Float(siblingIndex + 1) * 0.42
            let vertical = siblingIndex.isMultiple(of: 2) ? Float(0.28) : Float(-0.28)

            return parentPosition + SIMD3<Float>(offset, vertical, Float(siblingIndex) * 0.22)
        }

        let sunOrder = bodies
            .filter { $0.parentBodyId == nil || $0.parentBodyId == "sun" }
            .filter { $0.type != .star }
            .sorted { $0.displayOrder < $1.displayOrder }
        let orderIndex = sunOrder.firstIndex { $0.id == body.id } ?? 0
        let xPosition: Float

        switch settings.scaleMode {
        case .educational, .custom:
            xPosition = Float(orderIndex + 1) * 1.55
        case .compressedDistance:
            let normalized = normalizedSunDistance(for: body, maxSunDistance: maxSunDistance)
            let compression = Float(max(settings.distanceCompression, 5))
            let range = max(5.8, 14 - (compression / 10))
            xPosition = 1.2 + pow(Float(normalized), 0.42) * range
        case .trueDistance:
            let normalized = normalizedSunDistance(for: body, maxSunDistance: maxSunDistance)
            xPosition = 1.2 + pow(Float(normalized), 0.82) * 13.5
        }

        return SIMD3<Float>(xPosition, 0, 0)
    }

    private static func orbitRadius(
        for body: CelestialBody,
        settings: SolarSystemSceneSettings,
        maxSunDistance: Double
    ) -> Float? {
        guard settings.showOrbits,
              body.parentBodyId == nil || body.parentBodyId == "sun",
              body.type != .star else {
            return nil
        }

        switch settings.scaleMode {
        case .educational, .custom:
            return nil
        case .compressedDistance, .trueDistance:
            return abs(position(
                for: body,
                bodies: [body],
                parentPositions: [:],
                settings: settings,
                maxSunDistance: maxSunDistance
            ).x)
        }
    }

    private static func displayRadius(
        for body: CelestialBody,
        settings: SolarSystemSceneSettings
    ) -> Float {
        let multiplier = Float(settings.planetSizeMultiplier)

        switch body.type {
        case .star:
            return min(1.8, 0.62 * pow(multiplier, 0.42))
        case .satellite:
            return min(0.65, 0.05 * multiplier)
        case .moon, .asteroid, .dwarfPlanet:
            let baseRadius = max(0.07, Float(log10(body.radiusKm + 10)) / 18)
            return min(1.2, baseRadius * multiplier)
        case .planet:
            let baseRadius = max(0.11, Float(log10(body.radiusKm + 10)) / 14)
            return min(2.0, baseRadius * multiplier)
        }
    }

    private static func normalizedSunDistance(for body: CelestialBody, maxSunDistance: Double) -> Double {
        guard let distance = body.averageDistanceFromSunKm, distance > 0 else {
            return 0
        }

        return min(max(distance / maxSunDistance, 0), 1)
    }
}
