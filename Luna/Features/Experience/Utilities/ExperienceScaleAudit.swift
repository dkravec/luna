import Foundation

enum ExperienceScaleAudit {
    static func report(for bodies: [CelestialBody]) -> String {
        let cases: [(String, ExperienceSceneSettings)] = [
            ("Educational + Uniform", settings(distance: .educational, object: .uniform)),
            ("Educational + Relative", settings(distance: .educational, object: .relative)),
            ("Compressed + Relative", settings(distance: .compressed, object: .relative)),
            ("True Distance + True Size", settings(distance: .trueScale, object: .trueScale))
        ]

        return cases.map { title, settings in
            section(title: title, bodies: bodies, settings: settings)
        }
        .joined(separator: "\n\n")
    }

    private static func section(
        title: String,
        bodies: [CelestialBody],
        settings: ExperienceSceneSettings
    ) -> String {
        let snapshot = ExperienceSceneEngine.snapshot(for: bodies, settings: settings)
        let rows = snapshot.bodies.map { body in
            let rawDistance = body.body.averageDistanceFromSunKm ?? body.body.averageDistanceFromEarthKm ?? 0
            let warnings = warnings(for: body, snapshot: snapshot).joined(separator: ", ")
            return [
                body.body.name,
                "raw radius \(format(body.body.radiusKm)) km",
                "rendered radius \(format(Double(body.displayRadius)))",
                "distance \(format(rawDistance)) km",
                "position (\(format(Double(body.position.x))), \(format(Double(body.position.y))), \(format(Double(body.position.z))))",
                warnings.isEmpty ? nil : "warnings: \(warnings)"
            ]
            .compactMap { $0 }
            .joined(separator: " | ")
        }

        return ([title] + rows).joined(separator: "\n")
    }

    private static func warnings(for body: ExperienceSceneBody, snapshot: ExperienceSceneSnapshot) -> [String] {
        var warnings: [String] = []

        if body.displayRadius < 0.04 {
            warnings.append("very small")
        }

        if body.displayRadius > 0.65 {
            warnings.append("very large")
        }

        if body.body.id == "moon",
           let earth = snapshot.bodies.first(where: { $0.body.id == "earth" }) {
            let offset = body.position - earth.position
            let distance = sqrt(Double(offset.x * offset.x + offset.y * offset.y + offset.z * offset.z))
            if distance > 1.0 {
                warnings.append("moon too far from earth")
            }
        }

        return warnings
    }

    private static func settings(
        distance: DistanceScaleMode,
        object: ObjectScaleMode
    ) -> ExperienceSceneSettings {
        ExperienceSceneSettings(
            isAREnabled: false,
            distanceScaleMode: distance,
            objectScaleMode: object,
            distanceCompression: 30,
            orbitPlaybackSpeed: .standard,
            objectRotationSpeed: .slow,
            showLabels: true,
            showOrbits: true
        )
    }

    private static func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = value >= 10 ? 1 : 3
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
