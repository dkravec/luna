import Foundation

final class LocalCelestialBodyRepository: CelestialBodyRepository {
    private let bundle: Bundle
    private let resourceName: String
    private let decoder: JSONDecoder

    init(
        bundle: Bundle = .main,
        resourceName: String = "celestial_bodies",
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.bundle = bundle
        self.resourceName = resourceName
        self.decoder = decoder
    }

    func fetchBodies() throws -> [CelestialBody] {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw CelestialBodyRepositoryError.missingLocalDataFile("\(resourceName).json")
        }

        let data = try Data(contentsOf: url)
        let bodies = try decoder.decode([CelestialBody].self, from: data)
        return bodies.sorted { $0.displayOrder < $1.displayOrder }
    }

    func body(id: String) throws -> CelestialBody? {
        try fetchBodies().first { $0.id == id }
    }
}
