import Foundation

final class ExploreViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loaded
        case failed(String)
    }

    @Published private(set) var bodies: [CelestialBody] = []
    @Published private(set) var loadState: LoadState = .idle
    @Published var selectedFilter: BodyFilter = .all
    @Published var searchText: String = ""

    private var repository: CelestialBodyRepository?

    var filteredBodies: [CelestialBody] {
        let filteredByType = switch selectedFilter {
        case .all:
            bodies
        case .planets:
            bodies.filter { $0.type == .planet }
        case .moons:
            bodies.filter { $0.type == .moon }
        case .satellites:
            bodies.filter { $0.type == .satellite }
        case .nasa:
            bodies.filter { $0.exploreCollection == .iconicNASA }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return filteredByType }

        return filteredByType.filter { bodyMatches($0, query: query, includeCollectionTokens: true) }
    }

    var bodyCountText: String {
        "\(filteredBodies.count)"
    }

    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var exploreCollections: [ExploreCollection] {
        ExploreCollection.allCases.filter { collection in
            !bodies(in: collection).isEmpty
        }
    }

    func configure(repository: CelestialBodyRepository) {
        self.repository = repository

        if loadState == .idle {
            loadBodies()
        }
    }

    func loadBodies() {
        guard let repository else { return }

        do {
            bodies = try repository.fetchBodies()
            loadState = .loaded
        } catch {
            bodies = []
            loadState = .failed(error.localizedDescription)
        }
    }

    func children(of body: CelestialBody) -> [CelestialBody] {
        bodies.filter { $0.parentBodyId == body.id }
    }

    func bodies(in collection: ExploreCollection) -> [CelestialBody] {
        bodies.filter { $0.exploreCollection == collection }
    }

    func filteredBodies(in collection: ExploreCollection, searchText: String) -> [CelestialBody] {
        let categoryBodies = bodies(in: collection)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return categoryBodies }

        return categoryBodies.filter { bodyMatches($0, query: query, includeCollectionTokens: false) }
    }

    func bodyCount(in collection: ExploreCollection) -> Int {
        bodies(in: collection).count
    }

    private func bodyMatches(
        _ body: CelestialBody,
        query: String,
        includeCollectionTokens: Bool
    ) -> Bool {
        body.searchTokens(includeCollectionTokens: includeCollectionTokens)
            .contains { $0.localizedCaseInsensitiveContains(query) }
    }
}

enum BodyFilter: String, CaseIterable, Identifiable {
    case all
    case planets
    case moons
    case satellites
    case nasa

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .planets:
            return "Planets"
        case .moons:
            return "Moons"
        case .satellites:
            return "Satellites"
        case .nasa:
            return "NASA"
        }
    }
}

enum ExploreCollection: String, CaseIterable, Identifiable {
    case solarSystem
    case earthOrbit
    case iconicNASA

    var id: String { rawValue }

    var title: String {
        switch self {
        case .solarSystem:
            return "Solar System"
        case .earthOrbit:
            return "Earth Orbit"
        case .iconicNASA:
            return "Iconic NASA"
        }
    }

    var subtitle: String {
        switch self {
        case .solarSystem:
            return "Planets, moons, and nearby worlds"
        case .earthOrbit:
            return "NASA satellites around Earth"
        case .iconicNASA:
            return "Rockets, spacecraft, stations, and astronauts"
        }
    }

    var systemImage: String {
        switch self {
        case .solarSystem:
            return "sun.max"
        case .earthOrbit:
            return "globe.americas"
        case .iconicNASA:
            return "sparkles"
        }
    }

    var searchTokens: [String] {
        switch self {
        case .solarSystem:
            return ["solar system", "planet", "planets", "moon", "moons", "worlds"]
        case .earthOrbit:
            return ["earth orbit", "satellite", "satellites", "earth observation"]
        case .iconicNASA:
            return ["iconic nasa", "nasa", "rocket", "rockets", "spacecraft", "station", "astronaut"]
        }
    }
}

extension CelestialBody {
    var exploreCollection: ExploreCollection {
        switch type {
        case .star, .planet, .moon, .asteroid, .dwarfPlanet:
            return .solarSystem
        case .satellite:
            return .earthOrbit
        case .rocket, .spacecraft, .station, .astronaut:
            return .iconicNASA
        }
    }

    func searchTokens(includeCollectionTokens: Bool) -> [String] {
        var tokens = [
            name,
            type.title,
            subtitle,
            summary
        ] + tags

        if includeCollectionTokens {
            let collection = exploreCollection
            tokens.append(collection.title)
            tokens.append(collection.subtitle)
            tokens.append(contentsOf: collection.searchTokens)
        }

        return tokens
    }
}
