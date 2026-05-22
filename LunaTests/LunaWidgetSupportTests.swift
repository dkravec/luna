import XCTest
@testable import Luna
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

final class LunaWidgetSupportTests: XCTestCase {
    func testCatalogLoaderLoadsBundledCelestialBodies() {
        let bodies = catalogLoader().loadBodies()

        XCTAssertTrue(bodies.contains { $0.id == "earth" })
        XCTAssertTrue(bodies.contains { $0.id == "mars" })
        XCTAssertGreaterThan(bodies.count, 8)
    }

    func testFactContentUsesCatalogFactsInsteadOfWidgetTemplateFallback() throws {
        let source = contentSource()
        let content = source.factContent(for: try date(year: 2026, month: 5, day: 22))

        XCTAssertFalse(content.fact.contains("daily space catalog"))
        XCTAssertFalse(content.fact.isEmpty)
        XCTAssertNotEqual(content.body.name, "Luna")
    }

    func testFactContentChangesAcrossMultipleDays() throws {
        let source = contentSource()
        let contents = try (0..<10).map { offset in
            source.factContent(for: try date(year: 2026, month: 5, day: 1 + offset))
        }

        XCTAssertGreaterThan(Set(contents.map(\.body.id)).count, 1)
        XCTAssertGreaterThan(Set(contents.map(\.fact)).count, 1)
    }

    func testThumbnailResolverLoadsBundledArtifactPNG() throws {
        let url = LunaWidgetThumbnailResourceResolver.url(
            named: "apollo_lunar_module.png",
            bundle: Bundle(for: LunaAppState.self)
        )

        let resolvedURL = try XCTUnwrap(url)
        XCTAssertEqual(resolvedURL.lastPathComponent, "apollo_lunar_module.png")

#if os(iOS)
        let image = try XCTUnwrap(UIImage(contentsOfFile: resolvedURL.path))
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
#elseif os(macOS)
        let image = try XCTUnwrap(NSImage(contentsOf: resolvedURL))
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
#endif
    }

    func testSolarLayoutSpacesInnerPlanetOrbits() throws {
        let layout = solarLayout(size: CGSize(width: 140, height: 90))
        let innerRadii = ["mercury", "venus", "earth", "mars"].compactMap { id in
            layout.orbits.first { $0.bodyId == id }?.radius
        }

        XCTAssertEqual(innerRadii.count, 4, "\(layout.orbits.map(\.bodyId))")
        XCTAssertTrue(zip(innerRadii, innerRadii.dropFirst()).allSatisfy { $0 < $1 })
        XCTAssertGreaterThan(zip(innerRadii, innerRadii.dropFirst()).map { $1 - $0 }.min() ?? 0, 3)
    }

    func testSolarLayoutUsesProvidedDateForPlacements() throws {
        let size = CGSize(width: 300, height: 180)
        let first = solarLayout(size: size, date: try date(year: 2026, month: 5, day: 22))
        let second = solarLayout(size: size, date: try date(year: 2026, month: 6, day: 22))
        let firstMercury = try XCTUnwrap(first.placements.first { $0.id == "mercury" })
        let secondMercury = try XCTUnwrap(second.placements.first { $0.id == "mercury" })

        XCTAssertNotEqual(firstMercury.position.x, secondMercury.position.x, accuracy: 0.001)
        XCTAssertNotEqual(firstMercury.position.y, secondMercury.position.y, accuracy: 0.001)
    }

    func testSolarLayoutMatchesSharedPreviewProjectionForFixedDate() throws {
        let size = CGSize(width: 300, height: 180)
        let fixedDate = try date(year: 2026, month: 5, day: 22)
        let layout = solarLayout(size: size, date: fixedDate)
        let snapshot = solarSnapshot(date: fixedDate)
        let expectedLayout = LunaSolarPreviewLayout(
            snapshot: snapshot,
            size: size,
            bodySize: LunaSolarPreviewLayout.widgetBodySize(for:canvasSize:)
        )

        for placement in layout.placements {
            let expected = try XCTUnwrap(expectedLayout.placements.first { $0.id == placement.id })
            XCTAssertEqual(placement.position.x, expected.position.x, accuracy: 0.001, placement.id)
            XCTAssertEqual(placement.position.y, expected.position.y, accuracy: 0.001, placement.id)
        }
    }

    func testSolarLayoutKeepsPlacementsInsideCanvas() throws {
        let size = CGSize(width: 140, height: 90)
        let layout = solarLayout(size: size)

        for placement in layout.placements {
            let hasRings = placement.body.id == "saturn"
            let visualHalfWidth = (hasRings ? placement.bodySize * LunaSaturnRingMetrics.outerRadiusRatio : placement.bodySize) / 2
            let visualHalfHeight = max(
                placement.bodySize,
                hasRings ? placement.bodySize * LunaSaturnRingMetrics.outerRadiusRatio * LunaSaturnRingMetrics.ellipseHeightRatio : placement.bodySize
            ) / 2

            XCTAssertGreaterThanOrEqual(placement.position.x - visualHalfWidth, 0, placement.id)
            XCTAssertLessThanOrEqual(placement.position.x + visualHalfWidth, size.width, placement.id)
            XCTAssertGreaterThanOrEqual(placement.position.y - visualHalfHeight, 0, placement.id)
            XCTAssertLessThanOrEqual(placement.position.y + visualHalfHeight, size.height, placement.id)
        }
    }

    func testSaturnLayoutIncludesRingEnvelope() throws {
        let layout = solarLayout(size: CGSize(width: 300, height: 180))
        let saturn = try XCTUnwrap(layout.placements.first { $0.id == "saturn" })

        XCTAssertGreaterThan(saturn.bodySize * LunaSaturnRingMetrics.outerRadiusRatio, saturn.bodySize * 2)
        XCTAssertEqual(LunaSaturnRingMetrics.outerRadiusRatio, 2.33, accuracy: 0.001)
    }

    private func contentSource() -> LunaWidgetContentSource {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return LunaWidgetContentSource(catalogLoader: catalogLoader(), calendar: calendar)
    }

    private func catalogLoader() -> LunaWidgetCatalogLoader {
        LunaWidgetCatalogLoader(bundle: Bundle(for: LunaAppState.self))
    }

    private func solarLayout(size: CGSize, date: Date? = nil) -> LunaSolarPreviewLayout {
        let layoutDate = date ?? (try! self.date(year: 2026, month: 5, day: 22))
        return LunaSolarPreviewLayout(
            snapshot: solarSnapshot(date: layoutDate),
            size: size,
            bodySize: LunaSolarPreviewLayout.widgetBodySize(for:canvasSize:)
        )
    }

    private func solarSnapshot(date: Date) -> ExperienceSceneSnapshot {
        ExperienceSceneEngine.snapshot(
            for: contentSource().solarCelestialBodies(),
            settings: ExperienceSceneSettings(
                isAREnabled: false,
                sceneScaleProfile: .scaledRecommended,
                distanceScaleMode: .compressed,
                objectScaleMode: .relative,
                distanceCompression: 12,
                renderDetail: .balanced,
                orbitPlaybackSpeed: .standard,
                objectRotationSpeed: .slow,
                showLabels: false,
                showOrbits: true
            ),
            simulationDate: date
        )
    }

    private func date(year: Int, month: Int, day: Int) throws -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return try XCTUnwrap(components.date)
    }
}
