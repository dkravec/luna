import Foundation

protocol CelestialBodyRepository {
    func fetchBodies() throws -> [CelestialBody]
    func body(id: String) throws -> CelestialBody?
}

enum CelestialBodyRepositoryError: LocalizedError, CustomDebugStringConvertible {
    case missingLocalDataFile(String)
    case notImplemented(String)

    var errorDescription: String? {
        switch self {
        case .missingLocalDataFile(let filename):
            return "Luna could not find the local celestial body catalog: \(filename)."
        case .notImplemented(let repositoryName):
            return "\(repositoryName) is not implemented. Use LocalCelestialBodyRepository or provide a real remote data source."
        }
    }

    var debugDescription: String {
        errorDescription ?? String(describing: self)
    }
}
