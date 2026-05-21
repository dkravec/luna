import Foundation

final class RemoteCelestialBodyRepository: CelestialBodyRepository {
    func fetchBodies() throws -> [CelestialBody] {
        throw CelestialBodyRepositoryError.notImplemented("RemoteCelestialBodyRepository")
    }

    func body(id: String) throws -> CelestialBody? {
        throw CelestialBodyRepositoryError.notImplemented("RemoteCelestialBodyRepository")
    }
}
