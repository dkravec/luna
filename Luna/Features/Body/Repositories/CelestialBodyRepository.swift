import Foundation

protocol CelestialBodyRepository {
    func fetchBodies() throws -> [CelestialBody]
    func body(id: String) throws -> CelestialBody?
}

enum CelestialBodyRepositoryError: Error {
    case missingLocalDataFile(String)
}
