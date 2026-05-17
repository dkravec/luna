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
        case .stars:
            bodies.filter { $0.type == .star }
        case .planets:
            bodies.filter { $0.type == .planet }
        case .moons:
            bodies.filter { $0.type == .moon || $0.type == .satellite }
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
}

enum BodyFilter: String, CaseIterable, Identifiable {
    case all
    case stars
    case planets
    case moons

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .stars:
            return "Stars"
        case .planets:
            return "Planets"
        case .moons:
            return "Moons"
        }
    }
}
