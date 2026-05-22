import XCTest
@testable import Luna

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

    func testSolarLayoutSpacesInnerPlanetOrbits() throws {
        let layout = solarLayout(size: CGSize(width: 140, height: 90))
        let innerRadii = ["mercury", "venus", "earth", "mars"].compactMap { id in
            layout.orbits.first { $0.id == id }?.radius
        }

        XCTAssertEqual(innerRadii.count, 4)
        XCTAssertTrue(zip(innerRadii, innerRadii.dropFirst()).allSatisfy { $0 < $1 })
        XCTAssertGreaterThan(zip(innerRadii, innerRadii.dropFirst()).map { $1 - $0 }.min() ?? 0, 3)
    }

    func testSolarLayoutKeepsPlacementsInsideCanvas() throws {
        let size = CGSize(width: 140, height: 90)
        let layout = solarLayout(size: size)

        for placement in layout.placements {
            let visualHalfWidth = (placement.body.hasRings ? placement.size * 1.95 : placement.size) / 2
            let visualHalfHeight = max(placement.size, placement.body.hasRings ? placement.size * 0.92 : placement.size) / 2

            XCTAssertGreaterThanOrEqual(placement.position.x - visualHalfWidth, 0, placement.id)
            XCTAssertLessThanOrEqual(placement.position.x + visualHalfWidth, size.width, placement.id)
            XCTAssertGreaterThanOrEqual(placement.position.y - visualHalfHeight, 0, placement.id)
            XCTAssertLessThanOrEqual(placement.position.y + visualHalfHeight, size.height, placement.id)
        }
    }

    private func contentSource() -> LunaWidgetContentSource {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return LunaWidgetContentSource(catalogLoader: catalogLoader(), calendar: calendar)
    }

    private func catalogLoader() -> LunaWidgetCatalogLoader {
        LunaWidgetCatalogLoader(bundle: Bundle(for: LunaAppState.self))
    }

    private func solarLayout(size: CGSize) -> LunaWidgetSolarLayoutModel {
        LunaWidgetSolarLayoutModel(
            bodies: contentSource().solarBodies(),
            size: size,
            date: try! date(year: 2026, month: 5, day: 22)
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
