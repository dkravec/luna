import XCTest
@testable import Luna

final class HomeDailyContentProviderTests: XCTestCase {
    func testFeaturedBodyIsStableForSameCalendarDay() throws {
        let provider = provider()
        let morning = try date(year: 2026, month: 5, day: 19, hour: 8)
        let evening = try date(year: 2026, month: 5, day: 19, hour: 22)

        let first = provider.featuredBody(from: Self.bodies, date: morning)
        let second = provider.featuredBody(from: Self.bodies, date: evening)

        XCTAssertEqual(first?.id, second?.id)
    }

    func testFeaturedBodyChangesAcrossDatesWhenCatalogHasMultipleBodies() throws {
        let provider = provider()
        var selectedIDs: Set<String> = []

        for day in 1...8 {
            let selected = provider.featuredBody(
                from: Self.bodies,
                date: try date(year: 2026, month: 5, day: day)
            )
            if let id = selected?.id {
                selectedIDs.insert(id)
            }
        }

        XCTAssertGreaterThan(selectedIDs.count, 1)
    }

    func testFeaturedBodyKeepsSpecialBodiesPossibleButLessFrequent() throws {
        let provider = provider()
        let dates = try (1...28).map { day in
            try date(year: 2026, month: 5, day: day)
        }
        let selections = dates.compactMap { day in
            provider.featuredBody(from: Self.mixedBodies, date: day)
        }

        let specialSelections = selections.filter { isSpecialFeaturedBody($0) }
        let educationalSelections = selections.filter { !isSpecialFeaturedBody($0) }

        XCTAssertGreaterThan(educationalSelections.count, specialSelections.count)
        XCTAssertTrue(selections.contains { $0.id == "apollo_lunar_module" })
        XCTAssertTrue(selections.contains { $0.type == .astronaut })
    }

    func testDailyFactPrefersFeaturedBodyComputedData() throws {
        let provider = provider()
        let mars = try XCTUnwrap(Self.bodies.first { $0.id == "mars" })

        let fact = provider.dailyFact(
            featuredBody: mars,
            bodies: Self.bodies,
            date: try date(year: 2026, month: 5, day: 19)
        )

        XCTAssertTrue(fact.message.contains("Mars"))
        XCTAssertFalse(fact.message.isEmpty)
    }

    func testDailyFactFallsBackForSparseCatalog() throws {
        let provider = provider()
        let sparseBody = Self.makeBody(
            id: "plain",
            name: "Plain",
            radiusKm: 1,
            orbitalPeriodDays: nil,
            rotationPeriodHours: nil,
            gravity: nil,
            displayOrder: 0
        )

        let fact = provider.dailyFact(
            featuredBody: sparseBody,
            bodies: [sparseBody],
            date: try date(year: 2026, month: 5, day: 19)
        )

        XCTAssertEqual(fact.title, "Fact of the Day")
        XCTAssertTrue(fact.message.contains("1 body"))
    }

    func testSpecialBodyUsesCuratedMissionSummaryFact() throws {
        let provider = provider()
        let apollo = try XCTUnwrap(Self.mixedBodies.first { $0.id == "apollo_lunar_module" })

        let fact = provider.dailyFact(
            featuredBody: apollo,
            bodies: Self.mixedBodies,
            date: try date(year: 2026, month: 5, day: 19)
        )

        XCTAssertTrue(
            fact.message.contains("Apollo astronauts")
                || fact.message.contains("operate only in space")
        )
        XCTAssertFalse(fact.message.contains("wider than Earth"))
    }

    func testHistoryReturnsDailyContentInReverseChronologicalOrder() throws {
        let provider = provider()
        let endDate = try date(year: 2026, month: 5, day: 19)

        let history = provider.history(for: Self.bodies, endingAt: endDate, days: 4)

        XCTAssertEqual(history.count, 4)
        XCTAssertEqual(history.first, provider.content(for: Self.bodies, date: endDate))
        XCTAssertGreaterThan(Set(history.compactMap(\.featuredBody?.id)).count, 1)
    }

    private func provider() -> HomeDailyContentProvider {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return HomeDailyContentProvider(calendar: calendar)
    }

    private func date(year: Int, month: Int, day: Int, hour: Int = 12) throws -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return try XCTUnwrap(components.date)
    }

    private static let bodies: [CelestialBody] = [
        makeBody(id: "sun", name: "Sun", type: .star, radiusKm: 696_340, gravity: 274, parentBodyId: nil, displayOrder: 0),
        makeBody(id: "earth", name: "Earth", radiusKm: 6_371, averageDistanceFromSunKm: 149_600_000, gravity: 9.8, displayOrder: 1),
        makeBody(id: "moon", name: "Moon", type: .moon, radiusKm: 1_737.4, averageDistanceFromEarthKm: 384_400, orbitalPeriodDays: 27.3, parentBodyId: "earth", displayOrder: 2),
        makeBody(id: "mars", name: "Mars", radiusKm: 3_389.5, averageDistanceFromSunKm: 227_900_000, orbitalPeriodDays: 687, gravity: 3.7, displayOrder: 3)
    ]

    private static let mixedBodies: [CelestialBody] = [
        makeBody(id: "sun", name: "Sun", type: .star, radiusKm: 696_340, gravity: 274, parentBodyId: nil, displayOrder: 0),
        makeBody(id: "earth", name: "Earth", radiusKm: 6_371, averageDistanceFromSunKm: 149_600_000, gravity: 9.8, displayOrder: 1),
        makeBody(id: "moon", name: "Moon", type: .moon, radiusKm: 1_737.4, averageDistanceFromEarthKm: 384_400, orbitalPeriodDays: 27.3, parentBodyId: "earth", displayOrder: 2),
        makeBody(id: "mars", name: "Mars", radiusKm: 3_389.5, averageDistanceFromSunKm: 227_900_000, orbitalPeriodDays: 687, gravity: 3.7, displayOrder: 3),
        makeBody(id: "apollo_lunar_module", name: "Apollo Lunar Module", type: .spacecraft, radiusKm: 0.0045, summary: "The two-stage spacecraft that carried Apollo astronauts from lunar orbit down to the Moon's surface and back.", description: "The Apollo Lunar Module was built to operate only in space. Its descent stage landed on the Moon, while the ascent stage lifted crews back to the command module in lunar orbit.", parentBodyId: nil, displayOrder: 30),
        makeBody(id: "astronaut", name: "Astronaut", type: .astronaut, radiusKm: 0.001, summary: "A human trained to travel and work in space.", description: "Astronauts live and work in space environments that can challenge the body and mind.", parentBodyId: nil, displayOrder: 32)
    ]

    private static func makeBody(
        id: String,
        name: String,
        type: CelestialBodyType = .planet,
        radiusKm: Double,
        averageDistanceFromSunKm: Double? = nil,
        averageDistanceFromEarthKm: Double? = nil,
        orbitalPeriodDays: Double? = 365,
        rotationPeriodHours: Double? = 24,
        gravity: Double? = nil,
        summary: String = "",
        description: String = "",
        parentBodyId: String? = "sun",
        displayOrder: Int
    ) -> CelestialBody {
        CelestialBody(
            id: id,
            name: name,
            type: type,
            subtitle: "",
            summary: summary,
            description: description,
            radiusKm: radiusKm,
            averageDistanceFromSunKm: averageDistanceFromSunKm,
            averageDistanceFromEarthKm: averageDistanceFromEarthKm,
            orbitalPeriodDays: orbitalPeriodDays,
            rotationPeriodHours: rotationPeriodHours,
            axialTiltDegrees: nil,
            gravity: gravity,
            imageName: nil,
            thumbnailName: nil,
            textureName: nil,
            modelName: nil,
            orbit: nil,
            parentBodyId: parentBodyId,
            displayOrder: displayOrder,
            tags: []
        )
    }

    private func isSpecialFeaturedBody(_ body: CelestialBody) -> Bool {
        switch body.type {
        case .satellite, .rocket, .spacecraft, .station, .astronaut:
            return true
        case .star, .planet, .moon, .asteroid, .dwarfPlanet:
            return false
        }
    }
}
