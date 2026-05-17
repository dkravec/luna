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

        return filteredByType.filter { body in
            body.name.localizedCaseInsensitiveContains(query)
                || body.type.title.localizedCaseInsensitiveContains(query)
                || body.summary.localizedCaseInsensitiveContains(query)
        }
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
}
