import XCTest
import simd
@testable import Luna

final class ExperienceSceneEngineScaleTests: XCTestCase {
    func testTrueDistancePreservesPlanetDistanceRatios() throws {
        let snapshot = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .trueScale, object: .relative)
        )

        let mercury = try body("mercury", in: snapshot)
        let earth = try body("earth", in: snapshot)
        let neptune = try body("neptune", in: snapshot)

        XCTAssertEqual(
            distanceRatio(earth.position, mercury.position),
            sourceDistanceRatio("earth", "mercury"),
            accuracy: 0.06
        )
        XCTAssertEqual(
            distanceRatio(neptune.position, earth.position),
            sourceDistanceRatio("neptune", "earth"),
            accuracy: 0.06
        )
    }

    func testTrueDistanceOrbitPathMatchesPlacementScale() throws {
        let snapshot = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .trueScale, object: .relative)
        )

        let earth = try body("earth", in: snapshot)
        let earthOrbit = try XCTUnwrap(snapshot.orbitPaths.first { $0.bodyId == "earth" })
        let orbitRadius = earthOrbit.points
            .map { length($0) }
            .max() ?? 0

        XCTAssertEqual(
            Double(orbitRadius) / Double(length(earth.position)),
            1,
            accuracy: 0.01
        )
    }

    func testTrueDistanceMercuryClearsSunForEveryObjectScale() throws {
        for objectMode in ObjectScaleMode.allCases {
            let snapshot = ExperienceSceneEngine.snapshot(
                for: Self.bodies,
                settings: settings(distance: .trueScale, object: objectMode)
            )

            let sun = try body("sun", in: snapshot)
            let mercury = try body("mercury", in: snapshot)
            XCTAssertGreaterThan(
                length(mercury.position),
                sun.displayRadius + mercury.displayRadius + 0.01,
                "Mercury should clear the Sun in \(objectMode.rawValue)"
            )
        }
    }

    func testMoonClearsEarthInCompressedAndTrueDistanceModes() throws {
        for distanceMode in [DistanceScaleMode.compressed, .trueScale] {
            let snapshot = ExperienceSceneEngine.snapshot(
                for: Self.bodies,
                settings: settings(distance: distanceMode, object: .relative)
            )

            let earth = try body("earth", in: snapshot)
            let moon = try body("moon", in: snapshot)
            XCTAssertGreaterThan(
                length(moon.position - earth.position),
                earth.displayRadius + moon.displayRadius + 0.01,
                "Moon should clear Earth in \(distanceMode.rawValue)"
            )
        }
    }

    func testTrueSizePreservesRadiusRatios() throws {
        let snapshot = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .educational, object: .trueScale)
        )

        let sun = try body("sun", in: snapshot)
        let earth = try body("earth", in: snapshot)
        let moon = try body("moon", in: snapshot)
        let jupiter = try body("jupiter", in: snapshot)

        XCTAssertEqual(radiusRatio(earth, jupiter), sourceRadiusRatio("earth", "jupiter"), accuracy: 0.001)
        XCTAssertEqual(radiusRatio(moon, earth), sourceRadiusRatio("moon", "earth"), accuracy: 0.001)
        XCTAssertEqual(radiusRatio(sun, earth), sourceRadiusRatio("sun", "earth"), accuracy: 0.001)
    }

    func testReadableDistanceModesKeepExpectedSceneScale() {
        let educational = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .educational, object: .relative)
        )
        let compressed = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .compressed, object: .relative)
        )

        XCTAssertLessThan(educational.bounds.span, 25)
        XCTAssertLessThan(compressed.bounds.span, 30)
        XCTAssertGreaterThan(educational.bounds.span, 5)
        XCTAssertGreaterThan(compressed.bounds.span, 5)
    }

    func testEducationalRelativeBaselineStaysCompact() throws {
        let snapshot = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .educational, object: .relative)
        )

        let mercury = try body("mercury", in: snapshot)
        let venus = try body("venus", in: snapshot)
        let earth = try body("earth", in: snapshot)

        XCTAssertEqual(length(mercury.position), 1.18, accuracy: 0.02)
        XCTAssertEqual(length(venus.position), 2.36, accuracy: 0.02)
        XCTAssertEqual(length(earth.position), 3.54, accuracy: 0.02)
    }

    private static let bodies: [CelestialBody] = [
        makeBody(id: "sun", name: "Sun", type: .star, radiusKm: 696_340, parentBodyId: nil, displayOrder: 0),
        makeBody(id: "mercury", name: "Mercury", radiusKm: 2_439.7, averageDistanceFromSunKm: 57_900_000, orbit: orbit(57_909_050, eccentricity: 0.2056, inclination: 7.005, meanAnomaly: 174.796), displayOrder: 1),
        makeBody(id: "venus", name: "Venus", radiusKm: 6_051.8, averageDistanceFromSunKm: 108_200_000, orbit: orbit(108_208_000, eccentricity: 0.0068, inclination: 3.394, meanAnomaly: 50.115), displayOrder: 2),
        makeBody(id: "earth", name: "Earth", radiusKm: 6_371, averageDistanceFromSunKm: 149_600_000, orbit: orbit(149_598_023, eccentricity: 0.0167, inclination: 0, meanAnomaly: 358.617), displayOrder: 3),
        makeBody(id: "moon", name: "Moon", type: .moon, radiusKm: 1_737.4, averageDistanceFromSunKm: 149_600_000, averageDistanceFromEarthKm: 384_400, orbit: orbit(384_400, eccentricity: 0.0549, inclination: 5.145, meanAnomaly: 135.27), parentBodyId: "earth", displayOrder: 4),
        makeBody(id: "jupiter", name: "Jupiter", radiusKm: 69_911, averageDistanceFromSunKm: 778_500_000, orbit: orbit(778_570_000, eccentricity: 0.0489, inclination: 1.304, meanAnomaly: 20.020), displayOrder: 5),
        makeBody(id: "neptune", name: "Neptune", radiusKm: 24_622, averageDistanceFromSunKm: 4_495_100_000, orbit: orbit(4_495_060_000, eccentricity: 0.0113, inclination: 1.770, meanAnomaly: 256.228), displayOrder: 6)
    ]

    private static func makeBody(
        id: String,
        name: String,
        type: CelestialBodyType = .planet,
        radiusKm: Double,
        averageDistanceFromSunKm: Double? = nil,
        averageDistanceFromEarthKm: Double? = nil,
        orbit: CelestialOrbit? = nil,
        parentBodyId: String? = "sun",
        displayOrder: Int
    ) -> CelestialBody {
        CelestialBody(
            id: id,
            name: name,
            type: type,
            subtitle: "",
            summary: "",
            description: "",
            radiusKm: radiusKm,
            averageDistanceFromSunKm: averageDistanceFromSunKm,
            averageDistanceFromEarthKm: averageDistanceFromEarthKm,
            orbitalPeriodDays: 365,
            rotationPeriodHours: 24,
            axialTiltDegrees: nil,
            gravity: nil,
            imageName: nil,
            textureName: nil,
            modelName: nil,
            orbit: orbit,
            parentBodyId: parentBodyId,
            displayOrder: displayOrder,
            tags: []
        )
    }

    private static func orbit(
        _ semiMajorAxisKm: Double,
        eccentricity: Double,
        inclination: Double,
        meanAnomaly: Double
    ) -> CelestialOrbit {
        CelestialOrbit(
            semiMajorAxisKm: semiMajorAxisKm,
            eccentricity: eccentricity,
            inclinationDegrees: inclination,
            longitudeOfAscendingNodeDegrees: 0,
            argumentOfPeriapsisDegrees: 0,
            meanAnomalyAtEpochDegrees: meanAnomaly
        )
    }

    private func body(_ id: String, in snapshot: ExperienceSceneSnapshot) throws -> ExperienceSceneBody {
        try XCTUnwrap(snapshot.bodies.first { $0.id == id })
    }

    private func settings(distance: DistanceScaleMode, object: ObjectScaleMode) -> ExperienceSceneSettings {
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

    private func distanceRatio(_ lhs: SIMD3<Float>, _ rhs: SIMD3<Float>) -> Double {
        Double(length(lhs) / length(rhs))
    }

    private func sourceDistanceRatio(_ lhs: String, _ rhs: String) -> Double {
        sourceDistance(lhs) / sourceDistance(rhs)
    }

    private func sourceDistance(_ id: String) -> Double {
        let body = Self.bodies.first { $0.id == id }!
        return body.orbit?.semiMajorAxisKm ?? body.averageDistanceFromSunKm ?? body.averageDistanceFromEarthKm!
    }

    private func radiusRatio(_ lhs: ExperienceSceneBody, _ rhs: ExperienceSceneBody) -> Double {
        Double(lhs.displayRadius / rhs.displayRadius)
    }

    private func sourceRadiusRatio(_ lhs: String, _ rhs: String) -> Double {
        let lhsBody = Self.bodies.first { $0.id == lhs }!
        let rhsBody = Self.bodies.first { $0.id == rhs }!
        return lhsBody.radiusKm / rhsBody.radiusKm
    }
}
