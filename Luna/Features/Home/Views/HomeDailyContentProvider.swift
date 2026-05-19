import Foundation

struct HomeDailyContent: Equatable {
    let featuredBody: CelestialBody?
    let dailyFact: HomeDailyFact
}

struct HomeDailyFact: Equatable {
    let title: String
    let message: String
    let systemImage: String
}

struct HomeDailyContentProvider {
    var calendar: Calendar = .current

    func content(for bodies: [CelestialBody], date: Date = Date()) -> HomeDailyContent {
        let eligibleBodies = eligibleBodies(from: bodies)
        let featuredBody = featuredBody(from: eligibleBodies, date: date)
        let fact = dailyFact(featuredBody: featuredBody, bodies: eligibleBodies, date: date)

        return HomeDailyContent(featuredBody: featuredBody, dailyFact: fact)
    }

    func featuredBody(from bodies: [CelestialBody], date: Date = Date()) -> CelestialBody? {
        let eligibleBodies = eligibleBodies(from: bodies)
        guard !eligibleBodies.isEmpty else { return nil }

        let seed = dailySeed(for: date)
        return eligibleBodies[seed % eligibleBodies.count]
    }

    func dailyFact(featuredBody: CelestialBody?, bodies: [CelestialBody], date: Date = Date()) -> HomeDailyFact {
        let eligibleBodies = eligibleBodies(from: bodies)
        let candidates = factCandidates(featuredBody: featuredBody, bodies: eligibleBodies)
        guard !candidates.isEmpty else {
            let noun = eligibleBodies.count == 1 ? "body" : "bodies"
            return HomeDailyFact(
                title: "Fact of the Day",
                message: "Luna has \(eligibleBodies.count) \(noun) ready to explore.",
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
