import Foundation
import os

private let todayInLunaLogger = Logger(subsystem: "net.novapro.Luna", category: "TodayInLuna")

struct HomeDailyContent: Equatable {
    let date: Date
    let featuredBody: CelestialBody?
    let dailyFact: HomeDailyFact
    let relatedFacts: [HomeDailyFact]
}

struct HomeDailyFact: Equatable {
    let title: String
    let message: String
    let systemImage: String
}

private struct FeaturedBodySelection {
    let pool: TodayInLunaFeaturedPool
    let body: CelestialBody
    let reason: String
}

private enum TodayInLunaFeaturedPool: String, CaseIterable {
    case educational
    case special

    var selectionWeight: Int {
        switch self {
        case .educational:
            return 4
        case .special:
            return 1
        }
    }

    var selectionSalt: Int {
        switch self {
        case .educational:
            return 17
        case .special:
            return 53
        }
    }
}

struct HomeDailyContentProvider {
    var calendar: Calendar = .current

    func content(for bodies: [CelestialBody], date: Date = Date()) -> HomeDailyContent {
        let eligibleBodies = eligibleBodies(from: bodies)
        let selection = featuredBodySelection(from: eligibleBodies, date: date)
        let featuredBody = selection?.body
        let relatedFacts = factCandidates(featuredBody: featuredBody, bodies: eligibleBodies)
        let fact = dailyFact(from: relatedFacts, eligibleBodyCount: eligibleBodies.count, date: date)

        if let selection {
            let educationalCount = eligibleBodies.filter { $0.type.isEducationalFeaturedBody }.count
            let specialCount = eligibleBodies.filter { $0.type.isSpecialFeaturedBody }.count
            todayInLunaLogger.notice(
                "Today in Luna selection date=\(date.formatted(date: .numeric, time: .standard), privacy: .public) pool=\(selection.pool.rawValue, privacy: .public) body=\(selection.body.id, privacy: .public) reason=\(selection.reason, privacy: .public) candidates educational=\(educationalCount, privacy: .public) special=\(specialCount, privacy: .public) total=\(eligibleBodies.count, privacy: .public)"
            )
        }

        return HomeDailyContent(
            date: date,
            featuredBody: featuredBody,
            dailyFact: fact,
            relatedFacts: relatedFacts.isEmpty ? [fact] : relatedFacts
        )
    }

    func history(for bodies: [CelestialBody], endingAt date: Date = Date(), days: Int = 7) -> [HomeDailyContent] {
        guard days > 0 else { return [] }

        return (0..<days).compactMap { offset in
            guard let historyDate = calendar.date(byAdding: .day, value: -offset, to: date) else {
                return nil
            }

            return content(for: bodies, date: historyDate)
        }
    }

    func featuredBody(from bodies: [CelestialBody], date: Date = Date()) -> CelestialBody? {
        featuredBodySelection(from: bodies, date: date)?.body
    }

    func dailyFact(featuredBody: CelestialBody?, bodies: [CelestialBody], date: Date = Date()) -> HomeDailyFact {
        let eligibleBodies = eligibleBodies(from: bodies)
        let candidates = factCandidates(featuredBody: featuredBody, bodies: eligibleBodies)
        return dailyFact(from: candidates, eligibleBodyCount: eligibleBodies.count, date: date)
    }

    func relatedFacts(featuredBody: CelestialBody?, bodies: [CelestialBody]) -> [HomeDailyFact] {
        let eligibleBodies = eligibleBodies(from: bodies)
        return factCandidates(featuredBody: featuredBody, bodies: eligibleBodies)
    }

    private func featuredBodySelection(from bodies: [CelestialBody], date: Date) -> FeaturedBodySelection? {
        let eligibleBodies = eligibleBodies(from: bodies)
        let educationalBodies = eligibleBodies.filter { $0.type.isEducationalFeaturedBody }
        let specialBodies = eligibleBodies.filter { $0.type.isSpecialFeaturedBody }

        let availablePools: [(pool: TodayInLunaFeaturedPool, bodies: [CelestialBody])] = [
            (.educational, educationalBodies),
            (.special, specialBodies)
        ]
        .filter { !$0.bodies.isEmpty }

        guard !availablePools.isEmpty else { return nil }

        let selectedPool = weightedPool(for: date, availablePools: availablePools)
        let poolBodies = featuredBodies(in: selectedPool, from: eligibleBodies)
        guard !poolBodies.isEmpty else { return nil }

        let bodySeed = dailySeed(for: date, salt: selectedPool.selectionSalt)
        let selectedBody = poolBodies[bodySeed % poolBodies.count]
        let reason = availablePools.count == 1
            ? "only available pool"
            : "weighted roll across educational and special pools"

        return FeaturedBodySelection(pool: selectedPool, body: selectedBody, reason: reason)
    }

    private func weightedPool(
        for date: Date,
        availablePools: [(pool: TodayInLunaFeaturedPool, bodies: [CelestialBody])]
    ) -> TodayInLunaFeaturedPool {
        if availablePools.count == 1, let onlyPool = availablePools.first?.pool {
            return onlyPool
        }

        let totalWeight = availablePools.reduce(0) { $0 + $1.pool.selectionWeight }
        let roll = dailySeed(for: date, salt: 29) % totalWeight
        var runningTotal = 0

        for pool in availablePools {
            runningTotal += pool.pool.selectionWeight
            if roll < runningTotal {
                return pool.pool
            }
        }

        return availablePools[0].pool
    }

    private func featuredBodies(in pool: TodayInLunaFeaturedPool, from bodies: [CelestialBody]) -> [CelestialBody] {
        bodies.filter { body in
            switch pool {
            case .educational:
                return body.type.isEducationalFeaturedBody
            case .special:
                return body.type.isSpecialFeaturedBody
            }
        }
    }

    private func dailyFact(from candidates: [HomeDailyFact], eligibleBodyCount: Int, date: Date) -> HomeDailyFact {
        guard !candidates.isEmpty else {
            let noun = eligibleBodyCount == 1 ? "body" : "bodies"
            return HomeDailyFact(
                title: "Fact of the Day",
                message: "Luna has \(eligibleBodyCount) \(noun) ready to explore.",
                systemImage: "sparkles"
            )
        }

        let seed = dailySeed(for: date, salt: 17)
        return candidates[seed % candidates.count]
    }

    private func eligibleBodies(from bodies: [CelestialBody]) -> [CelestialBody] {
        bodies
            .filter { body in
                !body.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && body.radiusKm > 0
            }
            .sorted { lhs, rhs in
                if lhs.displayOrder == rhs.displayOrder {
                    return lhs.id < rhs.id
                }

                return lhs.displayOrder < rhs.displayOrder
            }
    }

    private func factCandidates(featuredBody: CelestialBody?, bodies: [CelestialBody]) -> [HomeDailyFact] {
        guard !bodies.isEmpty else { return [] }

        let featuredCandidates = featuredBody.map { factCandidates(for: $0, bodies: bodies) } ?? []
        if !featuredCandidates.isEmpty {
            return featuredCandidates
        }

        return bodies.flatMap { factCandidates(for: $0, bodies: bodies) }
    }

    private func factCandidates(for body: CelestialBody, bodies: [CelestialBody]) -> [HomeDailyFact] {
        if body.type.isSpecialFeaturedBody {
            return specialFactCandidates(for: body)
        }

        var facts: [HomeDailyFact] = []

        if let earth = bodies.first(where: { $0.id == "earth" }), earth.id != body.id, earth.radiusKm > 0 {
            let ratio = body.radiusKm / earth.radiusKm
            if ratio >= 1 {
                facts.append(HomeDailyFact(
                    title: "Fact of the Day",
                    message: "\(body.name) is about \(Self.shortNumber(ratio))x wider than Earth.",
                    systemImage: "ruler"
                ))
            } else if ratio > 0 {
                facts.append(HomeDailyFact(
                    title: "Fact of the Day",
                    message: "\(body.name) is about \(Self.shortNumber(1 / ratio))x narrower than Earth.",
                    systemImage: "ruler"
                ))
            }
        }

        if let gravity = body.gravity, gravity > 0 {
            facts.append(HomeDailyFact(
                title: "Fact of the Day",
                message: "Gravity on \(body.name) is about \(Self.shortNumber(gravity)) m/s2.",
                systemImage: "arrow.down"
            ))
        }

        if let distance = body.averageDistanceFromSunKm, distance > 0 {
            facts.append(HomeDailyFact(
                title: "Fact of the Day",
                message: "\(body.name) averages \(Self.distance(distance)) from the Sun.",
                systemImage: "sun.max"
            ))
        } else if let distance = body.averageDistanceFromEarthKm, distance > 0 {
            facts.append(HomeDailyFact(
                title: "Fact of the Day",
                message: "\(body.name) averages \(Self.distance(distance)) from Earth.",
                systemImage: "globe.americas"
            ))
        }

        if let orbitalPeriodDays = body.orbitalPeriodDays, orbitalPeriodDays > 0 {
            facts.append(HomeDailyFact(
                title: "Fact of the Day",
                message: "\(body.name) completes an orbit in about \(Self.days(orbitalPeriodDays)).",
                systemImage: "circle.dashed"
            ))
        }

        if let rotationPeriodHours = body.rotationPeriodHours, rotationPeriodHours != 0 {
            let direction = rotationPeriodHours < 0 ? "retrograde rotation" : "rotation"
            facts.append(HomeDailyFact(
                title: "Fact of the Day",
                message: "\(body.name) completes one \(direction) in about \(Self.hours(abs(rotationPeriodHours))).",
                systemImage: "rotate.3d"
            ))
        }

        let childCount = bodies.filter { $0.parentBodyId == body.id }.count
        if childCount > 0 {
            let noun = childCount == 1 ? "related body" : "related bodies"
            facts.append(HomeDailyFact(
                title: "Fact of the Day",
                message: "\(body.name) has \(childCount) \(noun) in Luna's catalog.",
                systemImage: "circle.grid.cross"
            ))
        }

        return facts
    }

    private func specialFactCandidates(for body: CelestialBody) -> [HomeDailyFact] {
        var facts: [HomeDailyFact] = []
        let trimmedSummary = body.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = body.description.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedSummary.isEmpty {
            facts.append(HomeDailyFact(
                title: "Fact of the Day",
                message: trimmedSummary,
                systemImage: body.type.todayInLunaSystemImage
            ))
        }

        if !trimmedDescription.isEmpty {
            let excerpt = Self.excerpt(from: trimmedDescription)
            if excerpt != trimmedSummary {
                facts.append(HomeDailyFact(
                    title: "Fact of the Day",
                    message: excerpt,
                    systemImage: body.type.todayInLunaSystemImage
                ))
            }
        }

        if facts.isEmpty {
            facts.append(HomeDailyFact(
                title: "Fact of the Day",
                message: "\(body.name) is one of Luna's special mission bodies.",
                systemImage: body.type.todayInLunaSystemImage
            ))
        }

        return facts
    }

    private func dailySeed(for date: Date, salt: Int = 0) -> Int {
        let components = calendar.dateComponents([.era, .year, .month, .day], from: date)
        var value = components.era ?? 1
        value = value &* 31 &+ (components.year ?? 0)
        value = value &* 31 &+ (components.month ?? 0)
        value = value &* 31 &+ (components.day ?? 0)
        value = value &* 31 &+ salt
        return abs(value)
    }

    private static func shortNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value >= 10 ? 1 : 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static func excerpt(from text: String, maximumLength: Int = 140) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maximumLength else { return trimmed }

        let endIndex = trimmed.index(trimmed.startIndex, offsetBy: maximumLength)
        let prefix = String(trimmed[..<endIndex])
        if let sentenceEnd = prefix.lastIndex(of: ".") {
            return String(prefix[..<sentenceEnd]).trimmingCharacters(in: .whitespacesAndNewlines) + "."
        }

        return prefix.trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private static func distance(_ value: Double) -> String {
        if value >= 1_000_000_000 {
            return "\(shortNumber(value / 1_000_000_000))B km"
        }

        if value >= 1_000_000 {
            return "\(shortNumber(value / 1_000_000))M km"
        }

        return "\(shortNumber(value)) km"
    }

    private static func days(_ value: Double) -> String {
        if value >= 365 {
            return "\(shortNumber(value / 365.25)) years"
        }

        return "\(shortNumber(value)) days"
    }

    private static func hours(_ value: Double) -> String {
        if value >= 48 {
            return "\(shortNumber(value / 24)) days"
        }

        return "\(shortNumber(value)) hours"
    }
}

private extension CelestialBodyType {
    var isEducationalFeaturedBody: Bool {
        switch self {
        case .star, .planet, .moon, .asteroid, .dwarfPlanet:
            return true
        case .satellite, .rocket, .spacecraft, .station, .astronaut:
            return false
        }
    }

    var isSpecialFeaturedBody: Bool {
        !isEducationalFeaturedBody
    }

    var todayInLunaSystemImage: String {
        switch self {
        case .star:
            return "sun.max"
        case .planet:
            return "circle"
        case .moon:
            return "moon"
        case .satellite:
            return "dot.radiowaves.left.and.right"
        case .rocket:
            return "airplane.departure"
        case .spacecraft:
            return "sparkles"
        case .station:
            return "rectangle.connected.to.line.below"
        case .astronaut:
            return "person"
        case .asteroid:
            return "seal"
        case .dwarfPlanet:
            return "circle.dotted"
        }
    }
}
