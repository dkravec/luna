import XCTest
import simd
@testable import Luna

final class ExperienceSceneEngineScaleTests: XCTestCase {
    func testTrueDistancePreservesPlanetDistanceRatios() throws {
        for objectMode in [ObjectScaleMode.uniform, .relative, .trueScale] {
            let snapshot = ExperienceSceneEngine.snapshot(
                for: Self.bodies,
                settings: settings(distance: .trueScale, object: objectMode)
            )

            let mercury = try body("mercury", in: snapshot)
            let earth = try body("earth", in: snapshot)
            let neptune = try body("neptune", in: snapshot)

            XCTAssertEqual(distanceRatio(earth.position, mercury.position), expectedSceneDistanceRatio("earth", "mercury", distance: .trueScale), accuracy: 0.02)
            XCTAssertEqual(distanceRatio(neptune.position, earth.position), expectedSceneDistanceRatio("neptune", "earth", distance: .trueScale), accuracy: 0.02)
        }
    }

    func testTrueDistanceOrbitPathUsesAphelionScale() throws {
        let snapshot = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .trueScale, object: .relative)
        )

        let earthOrbit = try XCTUnwrap(snapshot.orbitPaths.first { $0.bodyId == "earth" })
        let orbitRadius = earthOrbit.points
            .map { length($0) }
            .max() ?? 0

        XCTAssertEqual(
            Double(orbitRadius),
            aphelionDistance("earth", distance: .trueScale),
            accuracy: 0.01
        )
    }

    func testCompressedDistanceUsesReadableTrueDistanceDivisorForOuterOrbits() throws {
        let snapshot = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .compressed, object: .uniform, distanceCompression: 5)
        )

        XCTAssertEqual(
            try orbitRadius("neptune", in: snapshot),
            Float(aphelionDistance("neptune", distance: .compressed, distanceCompression: 5)),
            accuracy: 0.01
        )
    }

    func testCompressedDistanceSliderProducesVisibleSpanChanges() {
        let compressed2x = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .compressed, object: .relative, distanceCompression: 2)
        )
        let compressed5x = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .compressed, object: .relative, distanceCompression: 5)
        )
        let compressed50x = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .compressed, object: .relative, distanceCompression: 50)
        )

        XCTAssertGreaterThan(compressed2x.bounds.span, compressed5x.bounds.span * 1.7)
        XCTAssertGreaterThan(compressed5x.bounds.span, compressed50x.bounds.span * 1.7)
    }

    func testCompressedOuterOrbitUsesSourceRatioWhenClearanceDoesNotApply() throws {
        let snapshot = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .compressed, object: .uniform, distanceCompression: 5)
        )
        let neptuneRadius = try orbitRadius("neptune", in: snapshot)
        let expectedNeptuneRadius = Float(aphelionDistance("neptune", distance: .compressed, distanceCompression: 5))

        XCTAssertEqual(
            neptuneRadius / expectedNeptuneRadius,
            1,
            accuracy: 0.01
        )
    }

    func testCompressedDistanceClampsDivisorRange() throws {
        let belowMinimum = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .compressed, object: .uniform, distanceCompression: 1)
        )
        let atMinimum = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .compressed, object: .uniform, distanceCompression: 2)
        )
        let aboveMaximum = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .compressed, object: .uniform, distanceCompression: 100)
        )
        let atMaximum = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .compressed, object: .uniform, distanceCompression: 50)
        )

        XCTAssertEqual(
            try orbitRadius("neptune", in: belowMinimum),
            try orbitRadius("neptune", in: atMinimum),
            accuracy: 0.001
        )
        XCTAssertEqual(
            try orbitRadius("neptune", in: aboveMaximum),
            try orbitRadius("neptune", in: atMaximum),
            accuracy: 0.001
        )
    }

    func testTrueDistanceDoesNotInflateOrbitsForVisualClearance() throws {
        for objectMode in ObjectScaleMode.allCases {
            let snapshot = ExperienceSceneEngine.snapshot(
                for: Self.bodies,
                settings: settings(distance: .trueScale, object: objectMode)
            )

            let mercury = try body("mercury", in: snapshot)
            XCTAssertEqual(Double(length(mercury.position)), expectedSceneDistance("mercury", distance: .trueScale), accuracy: 0.01)
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

    func testTrueSizeDistanceModesHaveVisibleSunClearance() throws {
        let educational = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .educational, object: .trueScale)
        )
        let compressed = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .compressed, object: .trueScale)
        )

        XCTAssertGreaterThan(try sunClearance(for: "mercury", in: educational), 0.5)
        XCTAssertGreaterThan(try sunClearance(for: "mercury", in: compressed), 0.3)
    }

    func testBoundsIncludeOrbitPaths() throws {
        let snapshot = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .trueScale, object: .relative)
        )

        let farthestOrbitPoint = snapshot.orbitPaths
            .flatMap(\.points)
            .map { length($0 - snapshot.bounds.center) }
            .max() ?? 0

        XCTAssertGreaterThanOrEqual(snapshot.bounds.span / 2, farthestOrbitPoint - 0.02)
    }

    func testScaleProfileDefaultsToCompressedRelative() {
        XCTAssertEqual(SceneScaleProfile.scaledRecommended.defaultDistanceScaleMode, .compressed)
        XCTAssertEqual(SceneScaleProfile.scaledRecommended.defaultObjectScaleMode, .relative)
        XCTAssertEqual(SceneScaleProfile.uniform.defaultDistanceScaleMode, .compressed)
        XCTAssertEqual(SceneScaleProfile.uniform.defaultObjectScaleMode, .uniform)
        XCTAssertEqual(SceneScaleProfile.trueSize.defaultDistanceScaleMode, .trueScale)
        XCTAssertEqual(SceneScaleProfile.trueSize.defaultObjectScaleMode, .trueScale)
        XCTAssertEqual(SceneScaleProfile.custom.defaultDistanceScaleMode, .compressed)
        XCTAssertEqual(SceneScaleProfile.custom.defaultObjectScaleMode, .relative)
    }

    func testOrbitPathStoresOrientationAngles() throws {
        let snapshot = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .compressed, object: .relative)
        )
        let mercuryOrbit = try XCTUnwrap(snapshot.orbitPaths.first { $0.bodyId == "mercury" })

        XCTAssertEqual(Double(mercuryOrbit.yawRadians), 48.331 * .pi / 180, accuracy: 0.0001)
        XCTAssertEqual(Double(mercuryOrbit.pitchRadians), 7.005 * .pi / 180, accuracy: 0.0001)
        XCTAssertEqual(Double(mercuryOrbit.rollRadians), 29.124 * .pi / 180, accuracy: 0.0001)
    }

    func testTrueDistanceTrueSizeCameraFramingSupportsLargeSpan() {
        let snapshot = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .trueScale, object: .trueScale)
        )
        let metrics = SolarSystemSceneCameraMetrics(snapshot: snapshot)

        XCTAssertGreaterThan(metrics.cameraDistance, Double(snapshot.bounds.span))
        XCTAssertGreaterThan(metrics.zFar, metrics.cameraDistance + Double(snapshot.bounds.span) * 2)
    }

    func testRecommendedMercuryPerihelionClearsSun() throws {
        let snapshot = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .compressed, object: .relative)
        )
        let sun = try body("sun", in: snapshot)
        let mercury = try body("mercury", in: snapshot)
        let mercuryOrbit = try XCTUnwrap(snapshot.orbitPaths.first { $0.bodyId == "mercury" })
        let minimumOrbitDistance = mercuryOrbit.points.map { length($0) }.min() ?? 0

        XCTAssertGreaterThanOrEqual(
            minimumOrbitDistance,
            sun.displayRadius + mercury.displayRadius + 0.12 - 0.002
        )
    }

    func testTrueScaleUsesSamePhysicalUnitForRadiiAndDistances() throws {
        let snapshot = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .trueScale, object: .trueScale)
        )
        let sun = try body("sun", in: snapshot)
        let earth = try body("earth", in: snapshot)

        XCTAssertEqual(Double(sun.displayRadius), sourceRadius("sun") / Self.physicalKilometersPerSceneUnit, accuracy: 0.000001)
        XCTAssertEqual(Double(earth.displayRadius), sourceRadius("earth") / Self.physicalKilometersPerSceneUnit, accuracy: 0.000001)
        XCTAssertEqual(Double(length(earth.position)), expectedSceneDistance("earth", distance: .trueScale), accuracy: 0.001)
    }

    func testTrueScalePlanetsOrbitOutsideTrueScaleSun() throws {
        let snapshot = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .trueScale, object: .trueScale)
        )
        let sun = try body("sun", in: snapshot)

        for planet in snapshot.bodies where planet.body.parentBodyId == "sun" {
            XCTAssertGreaterThan(
                length(planet.position),
                sun.displayRadius + planet.displayRadius,
                "\(planet.body.name) should orbit outside the true-scale Sun"
            )
        }
    }

    func testDateBasedOrbitAdvancesAndReturnsAfterPeriod() throws {
        let start = Date(timeIntervalSince1970: (CelestialOrbit.j2000JulianDay - 2_440_587.5) * 86_400)
        let settings = settings(distance: .trueScale, object: .trueScale)
        let initial = ExperienceSceneEngine.snapshot(for: Self.bodies, settings: settings, simulationDate: start)
        let advanced = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings,
            simulationDate: start.addingTimeInterval(91.3125 * 86_400)
        )
        let returned = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings,
            simulationDate: start.addingTimeInterval(365.25 * 86_400)
        )

        let initialEarth = try body("earth", in: initial)
        let advancedEarth = try body("earth", in: advanced)
        let returnedEarth = try body("earth", in: returned)

        XCTAssertGreaterThan(length(advancedEarth.position - initialEarth.position), 0.25)
        XCTAssertLessThan(length(returnedEarth.position - initialEarth.position), 0.01)
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

        XCTAssertEqual(Double(length(mercury.position)), expectedSceneDistance("mercury", distance: .educational), accuracy: 0.02)
        XCTAssertEqual(Double(length(venus.position)), expectedSceneDistance("venus", distance: .educational), accuracy: 0.02)
        XCTAssertEqual(Double(length(earth.position)), expectedSceneDistance("earth", distance: .educational), accuracy: 0.02)
    }

    private static let bodies: [CelestialBody] = [
        makeBody(id: "sun", name: "Sun", type: .star, radiusKm: 696_340, parentBodyId: nil, displayOrder: 0),
        makeBody(id: "mercury", name: "Mercury", radiusKm: 2_439.7, averageDistanceFromSunKm: 57_900_000, orbit: orbit(57_909_050, eccentricity: 0.2056, inclination: 7.005, longitude: 48.331, periapsis: 29.124, meanAnomaly: 174.796), displayOrder: 1),
        makeBody(id: "venus", name: "Venus", radiusKm: 6_051.8, averageDistanceFromSunKm: 108_200_000, orbit: orbit(108_208_000, eccentricity: 0.0068, inclination: 3.394, longitude: 76.680, periapsis: 54.884, meanAnomaly: 50.115), displayOrder: 2),
        makeBody(id: "earth", name: "Earth", radiusKm: 6_371, averageDistanceFromSunKm: 149_600_000, orbit: orbit(149_598_023, eccentricity: 0.0167, inclination: 0, longitude: 0, periapsis: 114.208, meanAnomaly: 358.617), displayOrder: 3),
        makeBody(id: "moon", name: "Moon", type: .moon, radiusKm: 1_737.4, averageDistanceFromSunKm: 149_600_000, averageDistanceFromEarthKm: 384_400, orbit: orbit(384_400, eccentricity: 0.0549, inclination: 5.145, longitude: 125.08, periapsis: 318.15, meanAnomaly: 135.27), parentBodyId: "earth", displayOrder: 4),
        makeBody(id: "jupiter", name: "Jupiter", radiusKm: 69_911, averageDistanceFromSunKm: 778_500_000, orbit: orbit(778_570_000, eccentricity: 0.0489, inclination: 1.304, longitude: 100.464, periapsis: 273.867, meanAnomaly: 20.020), displayOrder: 5),
        makeBody(id: "neptune", name: "Neptune", radiusKm: 24_622, averageDistanceFromSunKm: 4_495_100_000, orbit: orbit(4_495_060_000, eccentricity: 0.0113, inclination: 1.770, longitude: 131.784, periapsis: 273.187, meanAnomaly: 256.228), displayOrder: 6)
    ]
    private static let physicalKilometersPerSceneUnit: Double = 316_553_521
    private static let compressedDistanceKilometersPerSceneUnit: Double = 74_900_000

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
        longitude: Double,
        periapsis: Double,
        meanAnomaly: Double
    ) -> CelestialOrbit {
        CelestialOrbit(
            semiMajorAxisKm: semiMajorAxisKm,
            eccentricity: eccentricity,
            inclinationDegrees: inclination,
            longitudeOfAscendingNodeDegrees: longitude,
            argumentOfPeriapsisDegrees: periapsis,
            meanAnomalyAtEpochDegrees: meanAnomaly
        )
    }

    private func body(_ id: String, in snapshot: ExperienceSceneSnapshot) throws -> ExperienceSceneBody {
        try XCTUnwrap(snapshot.bodies.first { $0.id == id })
    }

    private func orbitRadius(_ id: String, in snapshot: ExperienceSceneSnapshot) throws -> Float {
        let path = try XCTUnwrap(snapshot.orbitPaths.first { $0.bodyId == id })
        return path.points.map { length($0) }.max() ?? 0
    }

    private func sunClearance(for id: String, in snapshot: ExperienceSceneSnapshot) throws -> Float {
        let sun = try body("sun", in: snapshot)
        let target = try body(id, in: snapshot)
        return length(target.position - sun.position) - sun.displayRadius - target.displayRadius
    }

    private func settings(
        distance: DistanceScaleMode,
        object: ObjectScaleMode,
        distanceCompression: Double = 30
    ) -> ExperienceSceneSettings {
        ExperienceSceneSettings(
            isAREnabled: false,
            distanceScaleMode: distance,
            objectScaleMode: object,
            distanceCompression: distanceCompression,
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

    private func expectedSceneDistanceRatio(_ lhs: String, _ rhs: String, distance: DistanceScaleMode) -> Double {
        expectedSceneDistance(lhs, distance: distance) / expectedSceneDistance(rhs, distance: distance)
    }

    private func expectedSceneDistance(
        _ id: String,
        distance: DistanceScaleMode,
        distanceCompression: Double = 30
    ) -> Double {
        let body = Self.bodies.first { $0.id == id }!
        let semiMajorAxis = baseSceneSemiMajorAxis(for: body, distance: distance, distanceCompression: distanceCompression)
        return semiMajorAxis * eccentricRadiusScale(for: body)
    }

    private func aphelionDistance(
        _ id: String,
        distance: DistanceScaleMode,
        distanceCompression: Double = 30
    ) -> Double {
        let body = Self.bodies.first { $0.id == id }!
        let eccentricity = body.orbit?.eccentricity ?? 0
        return baseSceneSemiMajorAxis(for: body, distance: distance, distanceCompression: distanceCompression) * (1 + eccentricity)
    }

    private func baseSceneSemiMajorAxis(
        for body: CelestialBody,
        distance: DistanceScaleMode,
        distanceCompression: Double
    ) -> Double {
        switch distance {
        case .educational:
            return Double(max(body.displayOrder, 1)) * 1.18
        case .compressed:
            return sourceDistance(body.id) / Self.compressedDistanceKilometersPerSceneUnit / distanceCompression
        case .trueScale:
            return sourceDistance(body.id) / Self.physicalKilometersPerSceneUnit
        }
    }

    private func eccentricRadiusScale(for body: CelestialBody) -> Double {
        guard let orbit = body.orbit else { return 1 }
        let meanAnomaly = orbit.meanAnomalyAtEpochDegrees * .pi / 180
        let eccentricity = orbit.eccentricity
        var eccentricAnomaly = meanAnomaly

        for _ in 0..<8 {
            let delta = (eccentricAnomaly - eccentricity * sin(eccentricAnomaly) - meanAnomaly) / (1 - eccentricity * cos(eccentricAnomaly))
            eccentricAnomaly -= delta
            if abs(delta) < 0.000_000_1 { break }
        }

        return 1 - eccentricity * cos(eccentricAnomaly)
    }

    private func sourceDistance(_ id: String) -> Double {
        let body = Self.bodies.first { $0.id == id }!
        return body.orbit?.semiMajorAxisKm ?? body.averageDistanceFromSunKm ?? body.averageDistanceFromEarthKm!
    }

    private func sourceRadius(_ id: String) -> Double {
        let body = Self.bodies.first { $0.id == id }!
        return body.radiusKm
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
