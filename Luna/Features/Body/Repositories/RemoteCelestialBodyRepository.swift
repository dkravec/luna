import Foundation

final class RemoteCelestialBodyRepository: CelestialBodyRepository {
    func fetchBodies() throws -> [CelestialBody] {
        []
    }

    func body(id: String) throws -> CelestialBody? {
        nil
    }
}
