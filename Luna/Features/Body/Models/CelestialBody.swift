import Foundation

struct CelestialBody: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let type: CelestialBodyType
    let subtitle: String
    let summary: String
    let description: String
    let radiusKm: Double
    let averageDistanceFromSunKm: Double?
    let averageDistanceFromEarthKm: Double?
    let orbitalPeriodDays: Double?
    let rotationPeriodHours: Double?
    let gravity: Double?
    let imageName: String?
    let textureName: String?
    let modelName: String?
    let parentBodyId: String?
    let displayOrder: Int
    let tags: [String]
}

enum CelestialBodyType: String, Codable, CaseIterable, Identifiable {
    case star
    case planet
    case moon
    case satellite
    case asteroid
    case dwarfPlanet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .star:
            return "Star"
        case .planet:
            return "Planet"
        case .moon:
            return "Moon"
        case .satellite:
            return "Satellite"
        case .asteroid:
            return "Asteroid"
        case .dwarfPlanet:
            return "Dwarf Planet"
        }
    }
}
