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

    private var repository: CelestialBodyRepository?

    var filteredBodies: [CelestialBody] {
        switch selectedFilter {
        case .all:
            return bodies
        case .stars:
            return bodies.filter { $0.type == .star }
        case .planets:
            return bodies.filter { $0.type == .planet }
        case .moons:
            return bodies.filter { $0.type == .moon || $0.type == .satellite }
        }
    }

    var bodyCountText: String {
        "\(filteredBodies.count)"
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
