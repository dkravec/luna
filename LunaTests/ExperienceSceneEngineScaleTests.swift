import XCTest
import simd
import SceneKit
import ImageIO
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

    func testEllipticalOrbitPathCoversPerihelionAndAphelionAndInclination() throws {
        let snapshot = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .trueScale, object: .relative, renderDetail: .high)
        )
        let mercuryOrbit = try XCTUnwrap(snapshot.orbitPaths.first { $0.bodyId == "mercury" })
        let distances = mercuryOrbit.points.map { length($0) }

        XCTAssertEqual(
            Double(distances.min() ?? 0),
            perihelionDistance("mercury", distance: .trueScale),
            accuracy: 0.02
        )
        XCTAssertEqual(
            Double(distances.max() ?? 0),
            aphelionDistance("mercury", distance: .trueScale),
            accuracy: 0.02
        )
        XCTAssertGreaterThan(mercuryOrbit.points.map { abs($0.y) }.max() ?? 0, 0.01)
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

    func testMoonClearsEarthInEducationalMode() throws {
        let snapshot = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .educational, object: .relative)
        )

        let earth = try body("earth", in: snapshot)
        let moon = try body("moon", in: snapshot)
        XCTAssertGreaterThan(
            length(moon.position - earth.position),
            earth.displayRadius + moon.displayRadius + 0.01,
            "Educational mode should prioritize visual clearance"
        )
    }

    func testMoonClearsEarthInCompressedReadableModes() throws {
        for objectMode in [ObjectScaleMode.uniform, .relative] {
            let snapshot = ExperienceSceneEngine.snapshot(
                for: Self.bodies,
                settings: settings(distance: .compressed, object: objectMode)
            )

            let earth = try body("earth", in: snapshot)
            let moon = try body("moon", in: snapshot)

            XCTAssertGreaterThan(
                length(moon.position - earth.position),
                earth.displayRadius + moon.displayRadius + 0.01,
                "Compressed \(objectMode.title) mode should shrink and separate the Moon instead of hiding it inside Earth"
            )
        }
    }

    func testMoonUsesEarthRelativeOrbitInsteadOfSunDistance() throws {
        for distanceMode in [DistanceScaleMode.compressed, .trueScale] {
            let snapshot = ExperienceSceneEngine.snapshot(
                for: Self.bodies,
                settings: settings(distance: distanceMode, object: .trueScale)
            )

            let earth = try body("earth", in: snapshot)
            let moon = try body("moon", in: snapshot)
            let mars = try body("mars", in: snapshot)
            let moonDistanceFromEarth = Double(length(moon.position - earth.position))
            let moonDistanceFromMars = Double(length(moon.position - mars.position))

            XCTAssertEqual(
                moonDistanceFromEarth,
                expectedSceneDistance("moon", distance: distanceMode),
                accuracy: distanceMode == .trueScale ? 0.001 : 0.01
            )
            XCTAssertLessThan(moonDistanceFromEarth, moonDistanceFromMars * 0.05)
        }
    }

    func testMoonOrbitPathIsCenteredOnEarth() throws {
        let snapshot = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .trueScale, object: .trueScale)
        )
        let earth = try body("earth", in: snapshot)
        let moonOrbit = try XCTUnwrap(snapshot.orbitPaths.first { $0.bodyId == "moon" })
        let firstOrbitDistance = Double(length(moonOrbit.points[0] - earth.position))

        XCTAssertEqual(firstOrbitDistance, perihelionDistance("moon", distance: .trueScale), accuracy: 0.001)
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

        XCTAssertGreaterThanOrEqual(snapshot.bounds.span / 2, farthestOrbitPoint - 0.05)
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

    func testUniformProfileOverrideIgnoresStoredExperienceScaleModes() {
        var preferences = ExperiencePreferences.defaults
        preferences.sceneScaleProfile = .trueSize
        preferences.distanceScaleMode = .trueScale
        preferences.objectScaleMode = .trueScale

        let settings = ExperienceSceneSettings(
            isAREnabled: false,
            preferences: preferences,
            sceneScaleProfileOverride: .uniform
        )

        XCTAssertEqual(settings.sceneScaleProfile, .uniform)
        XCTAssertEqual(settings.distanceScaleMode, .compressed)
        XCTAssertEqual(settings.objectScaleMode, .uniform)
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

    func testInitialSceneCameraCentersOnSunWhenAvailable() throws {
        let snapshot = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .compressed, object: .relative)
        )
        let sun = try body("sun", in: snapshot)
        let metrics = SolarSystemSceneCameraMetrics(snapshot: snapshot, settings: settings(distance: .compressed, object: .relative))
        let limit = SceneCameraLimit(snapshot: snapshot, settings: settings(distance: .compressed, object: .relative))

        XCTAssertEqual(Float(metrics.subjectCenter.x), sun.position.x, accuracy: 0.0001)
        XCTAssertEqual(Float(metrics.subjectCenter.y), sun.position.y, accuracy: 0.0001)
        XCTAssertEqual(Float(metrics.subjectCenter.z), sun.position.z, accuracy: 0.0001)
        XCTAssertEqual(Float(limit.subjectCenter.x), sun.position.x, accuracy: 0.0001)
    }

    func testInitialSceneCameraUsesOverheadAngledView() {
        let sceneSettings = settings(distance: .compressed, object: .relative)
        let snapshot = ExperienceSceneEngine.snapshot(for: Self.bodies, settings: sceneSettings)
        let metrics = SolarSystemSceneCameraMetrics(snapshot: snapshot, settings: sceneSettings)
        let offset = SCNVector3(
            metrics.position.x - metrics.subjectCenter.x,
            metrics.position.y - metrics.subjectCenter.y,
            metrics.position.z - metrics.subjectCenter.z
        )

        XCTAssertGreaterThan(offset.y, offset.z * 1.05)
        XCTAssertLessThan(offset.y, offset.z * 1.55)
        XCTAssertGreaterThan(offset.z, 0)
        XCTAssertGreaterThan(offset.x, 0)
    }

    func testInitialSceneZoomUsesProfileSettings() {
        let recommendedSettings = settings(distance: .compressed, object: .relative, sceneScaleProfile: .scaledRecommended)
        let trueScaleSettings = settings(distance: .trueScale, object: .trueScale, sceneScaleProfile: .trueSize)
        let recommended = ExperienceSceneEngine.snapshot(for: Self.bodies, settings: recommendedSettings)
        let trueScale = ExperienceSceneEngine.snapshot(for: Self.bodies, settings: trueScaleSettings)

        let recommendedMetrics = SolarSystemSceneCameraMetrics(snapshot: recommended, settings: recommendedSettings)
        let trueScaleMetrics = SolarSystemSceneCameraMetrics(snapshot: trueScale, settings: trueScaleSettings)

        XCTAssertLessThanOrEqual(recommendedMetrics.orthographicScale, 19)
        XCTAssertGreaterThan(recommendedMetrics.orthographicScale, Double(recommended.bounds.span) * 0.78 + 2.2)
        XCTAssertGreaterThan(trueScaleMetrics.orthographicScale, recommendedMetrics.orthographicScale)
        XCTAssertEqual(trueScaleMetrics.orthographicScale, Double(trueScale.bounds.span + 2.6), accuracy: 0.001)
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

        XCTAssertEqual(Double(sun.displayRadius), trueScaleSceneUnits(sourceRadius("sun")), accuracy: 0.000001)
        XCTAssertEqual(Double(earth.displayRadius), trueScaleSceneUnits(sourceRadius("earth")), accuracy: 0.000001)
        XCTAssertEqual(Double(length(earth.position)), expectedSceneDistance("earth", distance: .trueScale), accuracy: 0.001)
    }

    func testTrueScaleEnvironmentIsLargerWhilePreservingRatios() throws {
        let snapshot = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .trueScale, object: .trueScale)
        )
        let sun = try body("sun", in: snapshot)
        let earth = try body("earth", in: snapshot)
        let neptune = try body("neptune", in: snapshot)

        XCTAssertEqual(radiusRatio(earth, sun), sourceRadiusRatio("earth", "sun"), accuracy: 0.0001)
        XCTAssertEqual(distanceRatio(neptune.position, earth.position), expectedSceneDistanceRatio("neptune", "earth", distance: .trueScale), accuracy: 0.02)
        XCTAssertGreaterThan(Double(length(earth.position)), sourceDistance("earth") / Self.physicalKilometersPerSceneUnit)
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
        XCTAssertLessThan(length(returnedEarth.position - initialEarth.position), 0.08)
    }

    func testSelectedFocusScaleStaysCloseToSelectedBody() throws {
        let snapshot = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .compressed, object: .relative)
        )
        let earth = try body("earth", in: snapshot)
        let moon = try body("moon", in: snapshot)
        let childEnvelope = length(moon.position - earth.position) + moon.displayRadius

        let earthScale = SolarSystemSceneFocusMetrics.focusedOrthographicScale(for: "earth", in: snapshot)
        let moonScale = SolarSystemSceneFocusMetrics.focusedOrthographicScale(for: "moon", in: snapshot)
        let earthVisibleDiameterRatio = Double(earth.displayRadius * 2) / earthScale

        XCTAssertLessThan(earthScale, Double(childEnvelope * 5.2))
        XCTAssertGreaterThanOrEqual(earthScale, Double(earth.displayRadius * 4.0))
        XCTAssertGreaterThanOrEqual(earthVisibleDiameterRatio, 0.40)
        XCTAssertLessThanOrEqual(earthVisibleDiameterRatio, 0.50)
        XCTAssertGreaterThanOrEqual(moonScale, 0.82)
        XCTAssertLessThanOrEqual(moonScale, 0.88)
    }

    func testSelectedPlaybackFocusPreservesCameraOffsetForSameBody() {
        let cameraPosition = SCNVector3(10, 5, 3)
        let previousTarget = SCNVector3(1, 0, -2)
        let nextTarget = SCNVector3(4, 2, -1)

        let nextPosition = VisualSceneFocusMath.cameraPositionFollowingTargetDelta(
            currentCameraPosition: cameraPosition,
            previousTarget: previousTarget,
            nextTarget: nextTarget,
            maximumDistance: 100
        )

        XCTAssertEqual(Float(nextPosition.x - nextTarget.x), Float(cameraPosition.x - previousTarget.x), accuracy: 0.0001)
        XCTAssertEqual(Float(nextPosition.y - nextTarget.y), Float(cameraPosition.y - previousTarget.y), accuracy: 0.0001)
        XCTAssertEqual(Float(nextPosition.z - nextTarget.z), Float(cameraPosition.z - previousTarget.z), accuracy: 0.0001)
    }

    func testSelectedPlaybackFocusClampsOnlyWhenOffsetExceedsLimit() {
        let nextPosition = VisualSceneFocusMath.cameraPositionFollowingTargetDelta(
            currentCameraPosition: SCNVector3(40, 0, 0),
            previousTarget: SCNVector3Zero,
            nextTarget: SCNVector3(2, 0, 0),
            maximumDistance: 12
        )

        XCTAssertEqual(Float(nextPosition.x), 14, accuracy: 0.0001)
        XCTAssertEqual(Float(nextPosition.y), 0, accuracy: 0.0001)
        XCTAssertEqual(Float(nextPosition.z), 0, accuracy: 0.0001)
    }

    func testManualFocusInteractionStaysActiveUntilAllGesturesEnd() {
        var interaction = VisualSceneFocusInteraction()

        interaction.begin()
        interaction.begin()
        XCTAssertTrue(interaction.isActive)
        XCTAssertFalse(interaction.end())
        XCTAssertTrue(interaction.isActive)
        XCTAssertTrue(interaction.end())
        XCTAssertFalse(interaction.isActive)
    }

    func testManualFocusCaptureStoresUserCameraOffsetWithoutSnapping() {
        let state = VisualSceneFocusMath.capturedState(
            bodyID: "moon",
            target: SCNVector3(2, 3, 4),
            cameraPosition: SCNVector3(7, 5, -1),
            orthographicScale: 1.8
        )

        XCTAssertEqual(state.bodyID, "moon")
        XCTAssertEqual(Float(state.cameraOffset.x), 5, accuracy: 0.0001)
        XCTAssertEqual(Float(state.cameraOffset.y), 2, accuracy: 0.0001)
        XCTAssertEqual(Float(state.cameraOffset.z), -5, accuracy: 0.0001)
        XCTAssertEqual(state.orthographicScale, 1.8, accuracy: 0.0001)
    }

    func testSelectedFocusChangeDetectionDistinguishesSameChangeAndClear() {
        let state = CameraFocusState(
            bodyID: "moon",
            target: SCNVector3Zero,
            cameraOffset: SCNVector3(0, 0, 1),
            orthographicScale: 1
        )

        XCTAssertFalse(VisualSceneFocusMath.selectionDidChange(current: state, nextBodyID: "moon"))
        XCTAssertTrue(VisualSceneFocusMath.selectionDidChange(current: state, nextBodyID: "earth"))
        XCTAssertTrue(VisualSceneFocusMath.selectionDidChange(current: state, nextBodyID: nil))
        XCTAssertFalse(VisualSceneFocusMath.selectionDidChange(current: nil, nextBodyID: nil))
    }

    func testTrueScaleCameraMetricsAndLimitsCoverFullBounds() {
        let sceneSettings = settings(distance: .trueScale, object: .trueScale, sceneScaleProfile: .trueSize)
        let snapshot = ExperienceSceneEngine.snapshot(for: Self.bodies, settings: sceneSettings)
        let metrics = SolarSystemSceneCameraMetrics(snapshot: snapshot, settings: sceneSettings)
        let limits = SceneCameraLimit(snapshot: snapshot, settings: sceneSettings)

        XCTAssertLessThanOrEqual(metrics.zNear, 0.001)
        XCTAssertGreaterThan(metrics.cameraDistance, Double(snapshot.bounds.span) * 1.5)
        XCTAssertGreaterThan(metrics.zFar, metrics.cameraDistance + Double(snapshot.bounds.span) * 3)
        XCTAssertGreaterThan(limits.maximumCameraDistance, snapshot.bounds.span * 2.5)
        XCTAssertLessThan(limits.minimumOrthographicScale, metrics.orthographicScale * 0.10)
    }

    func testArtifactObjectCameraUsesCloseFramingWhilePlanetObjectDoesNot() {
        let artifact = Self.makeBody(
            id: "saturn_v",
            name: "Saturn V",
            type: .rocket,
            radiusKm: 0.055,
            parentBodyId: nil,
            displayOrder: 1
        )
        let artifactSnapshot = ExperienceSceneEngine.snapshot(
            for: [artifact],
            settings: settings(distance: .compressed, object: .relative),
            content: .object("saturn_v")
        )
        let planetSnapshot = ExperienceSceneEngine.snapshot(
            for: [Self.makeBody(id: "earth", name: "Earth", radiusKm: 6_371, displayOrder: 1)],
            settings: settings(distance: .compressed, object: .relative),
            content: .object("earth")
        )

        let artifactMetrics = SolarSystemSceneCameraMetrics(
            snapshot: artifactSnapshot,
            settings: settings(distance: .compressed, object: .relative)
        )
        let planetMetrics = SolarSystemSceneCameraMetrics(
            snapshot: planetSnapshot,
            settings: settings(distance: .compressed, object: .relative)
        )

        XCTAssertTrue(SolarSystemSceneCameraMetrics.isArtifactObjectSnapshot(artifactSnapshot))
        XCTAssertFalse(SolarSystemSceneCameraMetrics.isArtifactObjectSnapshot(planetSnapshot))
        XCTAssertLessThan(artifactMetrics.cameraDistance, planetMetrics.cameraDistance)
        XCTAssertLessThan(artifactMetrics.orthographicScale, planetMetrics.orthographicScale)
    }

    func testOrbitRibbonMeshAndThicknessAreBounded() throws {
        let snapshot = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .compressed, object: .relative, renderDetail: .balanced)
        )
        let earthOrbit = try XCTUnwrap(snapshot.orbitPaths.first { $0.bodyId == "earth" })
        let thickness = SolarSystemSceneOrbitRibbon.thickness(cameraScale: 80, viewportHeight: 800)
        let mesh = SolarSystemSceneOrbitRibbon.mesh(points: earthOrbit.points, thickness: thickness)

        XCTAssertGreaterThan(thickness, 0)
        XCTAssertLessThanOrEqual(thickness, 0.058)
        XCTAssertEqual(mesh.vertices.count, earthOrbit.points.count * 2)
        XCTAssertEqual(mesh.indices.count, earthOrbit.points.count * 6)
    }

    func testOrbitRibbonThicknessRespondsToCameraDistance() {
        let near = SolarSystemSceneOrbitRibbon.thickness(
            cameraScale: 24,
            viewportHeight: 800,
            cameraDistance: 24
        )
        let far = SolarSystemSceneOrbitRibbon.thickness(
            cameraScale: 24,
            viewportHeight: 800,
            cameraDistance: 120
        )

        XCTAssertGreaterThan(far, near)
    }

    func testOrbitRibbonMeshIsFiniteForFlatAndVerticalPaths() {
        let paths: [[SIMD3<Float>]] = [
            [
                SIMD3<Float>(1, 0, 0),
                SIMD3<Float>(0, 0, 1),
                SIMD3<Float>(-1, 0, 0),
                SIMD3<Float>(0, 0, -1)
            ],
            [
                SIMD3<Float>(0, 1, 0),
                SIMD3<Float>(0, 0, 0.8),
                SIMD3<Float>(0, -1, 0),
                SIMD3<Float>(0, 0, -0.8)
            ]
        ]

        for points in paths {
            let mesh = SolarSystemSceneOrbitRibbon.mesh(points: points, thickness: 0.02)
            XCTAssertEqual(mesh.vertices.count, points.count * 2)
            XCTAssertTrue(mesh.vertices.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
        }
    }

    func testLabelScaleFollowsCameraZoomWithinBounds() {
        let zoomedInScale = SolarSystemSceneLabelScale.scale(for: 1.2)
        let zoomedOutScale = SolarSystemSceneLabelScale.scale(for: 12)
        let farScale = SolarSystemSceneLabelScale.scale(for: 80)

        XCTAssertLessThan(zoomedInScale, zoomedOutScale)
        XCTAssertGreaterThanOrEqual(zoomedInScale, 0.055)
        XCTAssertLessThanOrEqual(farScale, 0.28)
    }

    func testRotationHelpersSeparateTiltAndSpin() throws {
        let snapshot = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .compressed, object: .relative)
        )
        let earth = try body("earth", in: snapshot)
        let tilt = SolarSystemSceneRotation.tiltEuler(for: earth)
        let spin = SolarSystemSceneRotation.spinEuler(for: earth)

        XCTAssertEqual(Float(tilt.x), 0, accuracy: 0.0001)
        XCTAssertEqual(Float(tilt.y), 0, accuracy: 0.0001)
        XCTAssertEqual(Float(tilt.z), earth.axialTiltRadians, accuracy: 0.0001)
        XCTAssertEqual(Float(spin.x), 0, accuracy: 0.0001)
        XCTAssertEqual(Float(spin.y), earth.rotationAngleRadians, accuracy: 0.0001)
    }

    func testRotationTiltAxisMatchesRealityKitConvention() throws {
        let earth = try body("earth", in: ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .compressed, object: .relative)
        ))

        XCTAssertEqual(SolarSystemSceneRotation.axialTiltAxis, SIMD3<Float>(0, 0, 1))
        XCTAssertEqual(Float(SolarSystemSceneRotation.tiltEuler(for: earth).z), earth.axialTiltRadians, accuracy: 0.0001)

        let uranus = ExperienceSceneBody(
            body: Self.makeBody(id: "uranus", name: "Uranus", radiusKm: 25_362, displayOrder: 7),
            position: .zero,
            displayRadius: 0.2,
            interactionRadius: 0.2,
            labelPosition: .zero,
            rotationAngleRadians: 0,
            axialTiltRadians: Float(97.77 * .pi / 180)
        )
        XCTAssertEqual(Float(SolarSystemSceneRotation.tiltEuler(for: uranus).z), uranus.axialTiltRadians, accuracy: 0.0001)
    }

    func testBundledSceneModelLoaderLoadsNASAAssetAndFallsBackForMissingAsset() {
        XCTAssertNotNil(BundledSceneModelLoader.node(named: "apollo_lunar_module.glb"))
        XCTAssertNil(BundledSceneModelLoader.node(named: "missing-spacecraft.glb"))
    }

    func testBundledThumbnailImageLoaderLoadsNASAAssetAndFallsBackForMissingAsset() {
        XCTAssertNotNil(BundledThumbnailImageLoader.image(named: "apollo_lunar_module.png"))
        XCTAssertNil(BundledThumbnailImageLoader.image(named: "missing-spacecraft.png"))
    }

    func testSceneObjectAssetResolverPrefersModelThenThumbnailThenFallback() throws {
        let modelBody = Self.makeBody(
            id: "apollo_lunar_module",
            name: "Apollo Lunar Module",
            type: .spacecraft,
            radiusKm: 0.004,
            thumbnailName: "apollo_lunar_module.png",
            modelName: "apollo_lunar_module.glb",
            parentBodyId: nil,
            displayOrder: 1
        )
        let thumbnailBody = Self.makeBody(
            id: "thumbnail_only",
            name: "Thumbnail Only",
            type: .spacecraft,
            radiusKm: 0.004,
            thumbnailName: "apollo_lunar_module.png",
            modelName: nil,
            parentBodyId: nil,
            displayOrder: 2
        )
        let fallbackBody = Self.makeBody(
            id: "fallback_only",
            name: "Fallback Only",
            type: .spacecraft,
            radiusKm: 0.004,
            parentBodyId: nil,
            displayOrder: 3
        )

        guard case .model(let modelURL) = SceneObjectAssetResolver.resolve(for: modelBody) else {
            return XCTFail("Expected model asset")
        }
        XCTAssertEqual(modelURL.lastPathComponent, "apollo_lunar_module.glb")

        guard case .thumbnail(let thumbnailURL) = SceneObjectAssetResolver.resolve(for: thumbnailBody) else {
            return XCTFail("Expected thumbnail asset")
        }
        XCTAssertEqual(thumbnailURL.lastPathComponent, "apollo_lunar_module.png")

        XCTAssertEqual(SceneObjectAssetResolver.resolve(for: fallbackBody), .fallback)
    }

    func testSceneObjectAssetResolverFindsExistingModelDirectories() throws {
        let nasaModel = Self.makeBody(
            id: "saturn_v",
            name: "Saturn V",
            type: .rocket,
            radiusKm: 0.055,
            modelName: "saturn_v.glb",
            parentBodyId: nil,
            displayOrder: 1
        )
        let satelliteModel = Self.makeBody(
            id: "terra",
            name: "Terra",
            type: .satellite,
            radiusKm: 0.0034,
            modelName: "terra.glb",
            parentBodyId: nil,
            displayOrder: 2
        )
        let moonModel = Self.makeBody(
            id: "moon",
            name: "Moon",
            type: .moon,
            radiusKm: 1_737.4,
            modelName: "moon_small.glb",
            parentBodyId: "earth",
            displayOrder: 3
        )

        XCTAssertEqual(SceneObjectAssetResolver.modelURL(for: nasaModel)?.lastPathComponent, "saturn_v.glb")
        XCTAssertEqual(SceneObjectAssetResolver.modelURL(for: satelliteModel)?.lastPathComponent, "terra.glb")
        XCTAssertEqual(SceneObjectAssetResolver.modelURL(for: moonModel)?.lastPathComponent, "moon_small.glb")
    }

    func testBundledLoadersUseSharedResolverURLs() throws {
        let modelBody = Self.makeBody(
            id: "iss",
            name: "ISS",
            type: .station,
            radiusKm: 0.055,
            thumbnailName: "iss.png",
            modelName: "iss.glb",
            parentBodyId: nil,
            displayOrder: 1
        )

        XCTAssertNotNil(SceneObjectAssetResolver.modelURL(for: modelBody))
        XCTAssertNotNil(SceneObjectAssetResolver.thumbnailURL(for: modelBody))
        XCTAssertNotNil(BundledSceneModelLoader.node(named: modelBody.modelName))
        XCTAssertNotNil(BundledThumbnailImageLoader.image(named: modelBody.thumbnailName))
    }

    func testBundledPlanetTexturesUseSceneKitSafeRGBImages() throws {
        let bodies = try LocalCelestialBodyRepository(bundle: .main).fetchBodies()
        let texturedBodies = bodies.filter { $0.textureName != nil }

        XCTAssertFalse(texturedBodies.isEmpty)

        for body in texturedBodies {
            let textureName = try XCTUnwrap(body.textureName)
            let url = try XCTUnwrap(
                Bundle.main.url(
                    forResource: textureName,
                    withExtension: "jpg",
                    subdirectory: "Planets"
                ),
                "\(body.id) should resolve \(textureName).jpg"
            )
            let imageSource = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
            let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(imageSource, 0, nil))
            let colorModel = try XCTUnwrap(image.colorSpace?.model)
            let channelCount = image.bitsPerPixel / image.bitsPerComponent

            XCTAssertEqual(colorModel, .rgb, "\(body.id) texture must decode as RGB for SceneKit/Metal")
            XCTAssertGreaterThanOrEqual(channelCount, 3, "\(body.id) texture must not be single-channel grayscale")
        }
    }

    func testBundledArtifactModelsResolveWithoutDracoAndLoadGeometry() throws {
        let bodies = try LocalCelestialBodyRepository(bundle: .main).fetchBodies()
        let modelBodies = bodies.filter { body in
            body.modelName != nil && Self.usesBundledArtifactModel(body.type)
        }

        XCTAssertEqual(modelBodies.count, 10)

        for body in modelBodies {
            let modelName = try XCTUnwrap(body.modelName, body.id)
            let url = try XCTUnwrap(Self.modelURL(named: modelName), "\(body.id) should resolve \(modelName)")
            let extensions = try Self.glbExtensionsUsed(at: url)
            XCTAssertFalse(
                extensions.contains("KHR_draco_mesh_compression"),
                "\(body.id) should be bundled as an app-readable uncompressed GLB"
            )

            let fittedNode = try XCTUnwrap(
                BundledSceneModelLoader.fittedNode(named: modelName, targetLongestAxis: 1.2),
                "\(body.id) should load \(modelName)"
            )
            XCTAssertGreaterThan(
                BundledSceneModelLoader.longestAxis(for: fittedNode),
                1.1,
                "\(body.id) should produce visible geometry"
            )
        }
    }

    func testBundledSceneModelLoaderFitsModelToTargetAxis() throws {
        let fittedNode = try XCTUnwrap(BundledSceneModelLoader.fittedNode(
            named: "saturn_v.glb",
            targetLongestAxis: 1.4
        ))

        XCTAssertEqual(BundledSceneModelLoader.longestAxis(for: fittedNode), 1.4, accuracy: 0.05)
    }

    func testBundledSceneModelLoaderCentersFittedModel() throws {
        let fittedNode = try XCTUnwrap(BundledSceneModelLoader.fittedNode(
            named: "iss.glb",
            targetLongestAxis: 1.2
        ))

        let bounds = fittedNode.boundingBox
        let center = SCNVector3(
            (bounds.min.x + bounds.max.x) / 2,
            (bounds.min.y + bounds.max.y) / 2,
            (bounds.min.z + bounds.max.z) / 2
        )

        XCTAssertEqual(center.x, 0, accuracy: 0.08)
        XCTAssertEqual(center.y, 0, accuracy: 0.08)
        XCTAssertEqual(center.z, 0, accuracy: 0.08)
    }

    func testBundledSceneModelLoaderDebugBoundsIncludeNestedTransforms() throws {
        let root = SCNNode()
        let child = SCNNode(geometry: SCNBox(width: 2, height: 4, length: 6, chamferRadius: 0))
        child.position = SCNVector3(3, -2, 5)
        child.scale = SCNVector3(0.5, 2, 1)
        root.addChildNode(child)

        let bounds = try XCTUnwrap(BundledSceneModelLoader.debugBounds(for: root))

        XCTAssertEqual(Float(bounds.min.x), 2.5, accuracy: 0.0001)
        XCTAssertEqual(Float(bounds.max.x), 3.5, accuracy: 0.0001)
        XCTAssertEqual(Float(bounds.min.y), -6, accuracy: 0.0001)
        XCTAssertEqual(Float(bounds.max.y), 2, accuracy: 0.0001)
        XCTAssertEqual(Float(bounds.min.z), 2, accuracy: 0.0001)
        XCTAssertEqual(Float(bounds.max.z), 8, accuracy: 0.0001)
    }

    func testGLBMatrixAndQuaternionDebugConversionMatchSceneKitFields() throws {
        let matrixNode = try XCTUnwrap(BundledSceneModelLoader.debugNode(matrix: [
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            4, 5, 6, 1
        ]))

        XCTAssertEqual(Float(matrixNode.transform.m41), 4, accuracy: 0.0001)
        XCTAssertEqual(Float(matrixNode.transform.m42), 5, accuracy: 0.0001)
        XCTAssertEqual(Float(matrixNode.transform.m43), 6, accuracy: 0.0001)

        let quaternionNode = try XCTUnwrap(BundledSceneModelLoader.debugNode(rotation: [0, sqrt(0.5), 0, sqrt(0.5)]))
        XCTAssertEqual(Float(quaternionNode.orientation.x), 0, accuracy: 0.0001)
        XCTAssertEqual(Float(quaternionNode.orientation.y), Float(sqrt(0.5)), accuracy: 0.0001)
        XCTAssertEqual(Float(quaternionNode.orientation.z), 0, accuracy: 0.0001)
        XCTAssertEqual(Float(quaternionNode.orientation.w), Float(sqrt(0.5)), accuracy: 0.0001)
    }

    func testExploreSearchMatchesCategoryNames() {
        let viewModel = ExploreViewModel()
        viewModel.configure(repository: TestCelestialBodyRepository(bodies: [
            Self.makeBody(id: "earth", name: "Earth", radiusKm: 6371, displayOrder: 1),
            Self.makeBody(id: "terra", name: "Terra", type: .satellite, radiusKm: 0.0034, displayOrder: 2),
            Self.makeBody(id: "saturn_v", name: "Saturn V", type: .rocket, radiusKm: 0.055, parentBodyId: nil, displayOrder: 3)
        ]))
        viewModel.searchText = "NASA"

        XCTAssertEqual(viewModel.filteredBodies.map(\.id), ["terra", "saturn_v"])

        viewModel.searchText = "satellites"
        XCTAssertEqual(viewModel.filteredBodies.map(\.id), ["terra"])
    }

    func testExploreCategorySearchStaysWithinCategory() {
        let viewModel = ExploreViewModel()
        viewModel.configure(repository: TestCelestialBodyRepository(bodies: [
            Self.makeBody(id: "earth", name: "Earth", radiusKm: 6371, displayOrder: 1),
            Self.makeBody(id: "terra", name: "Terra", type: .satellite, radiusKm: 0.0034, displayOrder: 2),
            Self.makeBody(id: "saturn_v", name: "Saturn V", type: .rocket, radiusKm: 0.055, parentBodyId: nil, displayOrder: 3)
        ]))

        XCTAssertEqual(
            viewModel.filteredBodies(in: .earthOrbit, searchText: "saturn").map(\.id),
            []
        )
        XCTAssertEqual(
            viewModel.filteredBodies(in: .iconicNASA, searchText: "rocket").map(\.id),
            ["saturn_v"]
        )
    }

#if os(iOS)
    func testAROrbitBudgetCapsBalancedPathSamples() throws {
        let snapshot = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .compressed, object: .relative, renderDetail: .balanced)
        )
        let earthOrbit = try XCTUnwrap(snapshot.orbitPaths.first { $0.bodyId == "earth" })
        let budget = ARSceneOrbitRenderBudget(path: earthOrbit, detail: .balanced, scale: 0.095, center: .zero)

        XCTAssertEqual(earthOrbit.points.count, 144)
        XCTAssertLessThanOrEqual(budget.meshPoints.count, 72)
    }

    func testAROrbitBudgetCapsHighPathSamples() throws {
        let snapshot = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .compressed, object: .relative, renderDetail: .high)
        )
        let earthOrbit = try XCTUnwrap(snapshot.orbitPaths.first { $0.bodyId == "earth" })
        let budget = ARSceneOrbitRenderBudget(path: earthOrbit, detail: .high, scale: 0.095, center: .zero)

        XCTAssertEqual(earthOrbit.points.count, 288)
        XCTAssertLessThanOrEqual(budget.meshPoints.count, 96)
    }

    func testAROrbitBudgetUsesOneRenderItemPerCompleteOrbit() {
        let snapshot = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .compressed, object: .relative, renderDetail: .high)
        )

        for orbitPath in snapshot.orbitPaths {
            let budget = ARSceneOrbitRenderBudget(path: orbitPath, detail: .high, scale: 0.095, center: .zero)
            XCTAssertEqual(budget.renderItemCount, 1, "\(orbitPath.id) should render as one AR mesh item")
        }
    }

    func testAROrbitFallbackDotsAreBoundedByStride() throws {
        let snapshot = ExperienceSceneEngine.snapshot(
            for: Self.bodies,
            settings: settings(distance: .compressed, object: .relative, renderDetail: .high)
        )
        let earthOrbit = try XCTUnwrap(snapshot.orbitPaths.first { $0.bodyId == "earth" })
        let budget = ARSceneOrbitRenderBudget(path: earthOrbit, detail: .high, scale: 0.095, center: .zero)
        let expectedMaximumDotCount = Int(ceil(Double(earthOrbit.points.count) / Double(SceneRenderDetail.high.arOrbitStride)))

        XCTAssertLessThanOrEqual(budget.fallbackDotPoints.count, expectedMaximumDotCount)
    }
#endif

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

    func testObjectCameraMetricsCoverObjectSnapshotBounds() {
        let artifact = Self.makeBody(
            id: "astronaut",
            name: "Astronaut",
            type: .astronaut,
            radiusKm: 0.001,
            parentBodyId: nil,
            displayOrder: 1
        )
        let snapshot = ExperienceSceneEngine.snapshot(
            for: [artifact],
            settings: settings(distance: .compressed, object: .relative),
            content: .object("astronaut")
        )
        let metrics = SolarSystemSceneCameraMetrics(snapshot: snapshot, settings: settings(distance: .compressed, object: .relative))

        XCTAssertGreaterThan(metrics.zFar, metrics.cameraDistance + Double(snapshot.bounds.span) * 4)
        XCTAssertGreaterThanOrEqual(metrics.orthographicScale, Double(snapshot.bounds.span))
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

    func testRemoteCelestialBodyRepositoryThrowsNotImplemented() {
        let repository = RemoteCelestialBodyRepository()

        XCTAssertThrowsError(try repository.fetchBodies()) { error in
            guard case CelestialBodyRepositoryError.notImplemented(let repositoryName) = error else {
                return XCTFail("Expected notImplemented, got \(error)")
            }
            XCTAssertEqual(repositoryName, "RemoteCelestialBodyRepository")
        }

        XCTAssertThrowsError(try repository.body(id: "earth")) { error in
            guard case CelestialBodyRepositoryError.notImplemented = error else {
                return XCTFail("Expected notImplemented, got \(error)")
            }
        }
    }

    func testNASAImageOfTheDayIdentityIsStableForSameSource() throws {
        let date = try XCTUnwrap(NASAAPODSharedCache.dateFormatter.date(from: "2026-05-21"))
        let url = try XCTUnwrap(URL(string: "https://example.com/apod.jpg"))
        let first = NASAImageOfTheDay(
            title: "APOD",
            date: date,
            explanation: "A picture",
            mediaType: "image",
            url: url,
            hdurl: nil,
            thumbnailURL: nil,
            copyright: nil
        )
        let second = NASAImageOfTheDay(
            title: "APOD",
            date: date,
            explanation: "A picture",
            mediaType: "image",
            url: url,
            hdurl: nil,
            thumbnailURL: nil,
            copyright: nil
        )

        XCTAssertEqual(first.id, second.id)
    }

    func testNASAAPODClientEndpointIncludesSharedQueryItems() throws {
        let date = try XCTUnwrap(NASAAPODSharedCache.dateFormatter.date(from: "2026-05-21"))
        let components = try XCTUnwrap(URLComponents(url: NASAAPODClient.endpoint(date: date), resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })

        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "api.nasa.gov")
        XCTAssertEqual(components.path, "/planetary/apod")
        XCTAssertEqual(query["api_key"], NASAAPODClient.apiKey)
        XCTAssertEqual(query["thumbs"], "true")
        XCTAssertEqual(query["date"], "2026-05-21")
    }

    func testBodyDetailComputesNestedRelatedBodiesFromFullCatalog() throws {
        let earth = try XCTUnwrap(Self.bodies.first { $0.id == "earth" })
        let moon = try XCTUnwrap(Self.bodies.first { $0.id == "moon" })
        let crater = Self.makeBody(
            id: "crater",
            name: "Crater",
            type: .asteroid,
            radiusKm: 1,
            parentBodyId: "moon",
            displayOrder: 99
        )
        let allBodies = Self.bodies + [crater]
        let view = BodyDetailView(
            celestialBody: earth,
            childBodies: [moon],
            allBodies: allBodies
        )

        XCTAssertEqual(view.children(of: moon).map(\.id), ["crater"])
    }

    func testExperienceSceneReadinessOnlyBecomesReadyAfterCallback() {
        var readiness = ExperienceSceneReadiness()

        XCTAssertFalse(readiness.isReady)
        readiness.markReady(for: .visual)
        XCTAssertTrue(readiness.isReady)
        XCTAssertEqual(readiness.readyMode, .visual)
        readiness.reset()
        XCTAssertFalse(readiness.isReady)
    }

    private static let bodies: [CelestialBody] = [
        makeBody(id: "sun", name: "Sun", type: .star, radiusKm: 696_340, parentBodyId: nil, displayOrder: 0),
        makeBody(id: "mercury", name: "Mercury", radiusKm: 2_439.7, averageDistanceFromSunKm: 57_900_000, orbit: orbit(57_909_050, eccentricity: 0.2056, inclination: 7.005, longitude: 48.331, periapsis: 29.124, meanAnomaly: 174.796), displayOrder: 1),
        makeBody(id: "venus", name: "Venus", radiusKm: 6_051.8, averageDistanceFromSunKm: 108_200_000, orbit: orbit(108_208_000, eccentricity: 0.0068, inclination: 3.394, longitude: 76.680, periapsis: 54.884, meanAnomaly: 50.115), displayOrder: 2),
        makeBody(id: "earth", name: "Earth", radiusKm: 6_371, averageDistanceFromSunKm: 149_600_000, orbit: orbit(149_598_023, eccentricity: 0.0167, inclination: 0, longitude: 0, periapsis: 114.208, meanAnomaly: 358.617), displayOrder: 3),
        makeBody(id: "moon", name: "Moon", type: .moon, radiusKm: 1_737.4, averageDistanceFromSunKm: 149_600_000, averageDistanceFromEarthKm: 384_400, orbit: orbit(384_400, eccentricity: 0.0549, inclination: 5.145, longitude: 125.08, periapsis: 318.15, meanAnomaly: 135.27), parentBodyId: "earth", displayOrder: 4),
        makeBody(id: "mars", name: "Mars", radiusKm: 3_389.5, averageDistanceFromSunKm: 227_900_000, orbit: orbit(227_939_200, eccentricity: 0.0934, inclination: 1.850, longitude: 49.558, periapsis: 286.502, meanAnomaly: 19.412), displayOrder: 5),
        makeBody(id: "jupiter", name: "Jupiter", radiusKm: 69_911, averageDistanceFromSunKm: 778_500_000, orbit: orbit(778_570_000, eccentricity: 0.0489, inclination: 1.304, longitude: 100.464, periapsis: 273.867, meanAnomaly: 20.020), displayOrder: 6),
        makeBody(id: "neptune", name: "Neptune", radiusKm: 24_622, averageDistanceFromSunKm: 4_495_100_000, orbit: orbit(4_495_060_000, eccentricity: 0.0113, inclination: 1.770, longitude: 131.784, periapsis: 273.187, meanAnomaly: 256.228), displayOrder: 7)
    ]
    private static let physicalKilometersPerSceneUnit: Double = 316_553_521
    private static let trueScaleEnvironmentMultiplier: Double = 6
    private static let compressedDistanceKilometersPerSceneUnit: Double = 74_900_000

    private static func makeBody(
        id: String,
        name: String,
        type: CelestialBodyType = .planet,
        radiusKm: Double,
        averageDistanceFromSunKm: Double? = nil,
        averageDistanceFromEarthKm: Double? = nil,
        orbit: CelestialOrbit? = nil,
        thumbnailName: String? = nil,
        modelName: String? = nil,
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
            thumbnailName: thumbnailName,
            textureName: nil,
            modelName: modelName,
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

    private static func usesBundledArtifactModel(_ type: CelestialBodyType) -> Bool {
        switch type {
        case .satellite, .rocket, .spacecraft, .station, .astronaut:
            return true
        case .star, .planet, .moon, .asteroid, .dwarfPlanet:
            return false
        }
    }

    private static func modelURL(named modelName: String) -> URL? {
        let resourceName = (modelName as NSString).deletingPathExtension
        let resourceExtension = (modelName as NSString).pathExtension.isEmpty
            ? "glb"
            : (modelName as NSString).pathExtension

        for subdirectory in ["NASA", "Satellites", "Moons"] {
            if let url = Bundle.main.url(
                forResource: resourceName,
                withExtension: resourceExtension,
                subdirectory: subdirectory
            ) {
                return url
            }
        }

        return Bundle.main.url(forResource: resourceName, withExtension: resourceExtension)
    }

    private static func glbExtensionsUsed(at url: URL) throws -> [String] {
        let data = try Data(contentsOf: url)
        var offset = 12

        while offset + 8 <= data.count {
            let chunkLength = Int(data.testUInt32(at: offset))
            let chunkType = data.testUInt32(at: offset + 4)
            let chunkStart = offset + 8
            let chunkEnd = chunkStart + chunkLength
            guard chunkEnd <= data.count else { break }

            if chunkType == 0x4E4F_534A,
               let json = try JSONSerialization.jsonObject(
                with: data.subdata(in: chunkStart..<chunkEnd)
               ) as? [String: Any] {
                return json["extensionsUsed"] as? [String] ?? []
            }

            offset = chunkEnd
        }

        return []
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
        distanceCompression: Double = 30,
        renderDetail: SceneRenderDetail = .balanced,
        sceneScaleProfile: SceneScaleProfile = .custom
    ) -> ExperienceSceneSettings {
        ExperienceSceneSettings(
            isAREnabled: false,
            sceneScaleProfile: sceneScaleProfile,
            distanceScaleMode: distance,
            objectScaleMode: object,
            distanceCompression: distanceCompression,
            renderDetail: renderDetail,
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

    private func perihelionDistance(
        _ id: String,
        distance: DistanceScaleMode,
        distanceCompression: Double = 30
    ) -> Double {
        let body = Self.bodies.first { $0.id == id }!
        let eccentricity = body.orbit?.eccentricity ?? 0
        return baseSceneSemiMajorAxis(for: body, distance: distance, distanceCompression: distanceCompression) * (1 - eccentricity)
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
            return trueScaleSceneUnits(sourceDistance(body.id))
        }
    }

    private func trueScaleSceneUnits(_ kilometers: Double) -> Double {
        kilometers / Self.physicalKilometersPerSceneUnit * Self.trueScaleEnvironmentMultiplier
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

private extension Data {
    func testUInt32(at offset: Int) -> UInt32 {
        subdata(in: offset..<(offset + 4)).withUnsafeBytes {
            UInt32(littleEndian: $0.load(as: UInt32.self))
        }
    }
}

private struct TestCelestialBodyRepository: CelestialBodyRepository {
    let bodies: [CelestialBody]

    func fetchBodies() throws -> [CelestialBody] {
        bodies
    }

    func body(id: String) throws -> CelestialBody? {
        bodies.first { $0.id == id }
    }
}
