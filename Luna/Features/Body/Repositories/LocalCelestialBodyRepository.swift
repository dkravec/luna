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
        validateTextureReferences(in: bodies)
        return bodies.sorted { $0.displayOrder < $1.displayOrder }
    }

    func body(id: String) throws -> CelestialBody? {
        try fetchBodies().first { $0.id == id }
    }

    private func validateTextureReferences(in bodies: [CelestialBody]) {
#if DEBUG
        let missingTextures = bodies.compactMap { body -> String? in
            guard let textureName = body.textureName else { return nil }

            let textureURL = bundle.url(
                forResource: textureName,
                withExtension: "jpg",
                subdirectory: "Planets"
            )

            return textureURL == nil ? "\(body.id): \(textureName).jpg" : nil
        }

        if !missingTextures.isEmpty {
            assertionFailure("Missing celestial body textures: \(missingTextures.joined(separator: ", "))")
        }
#endif
    }
}
