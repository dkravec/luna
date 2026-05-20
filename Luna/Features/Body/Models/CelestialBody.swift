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
    let axialTiltDegrees: Double?
    let gravity: Double?
    let imageName: String?
    let thumbnailName: String?
    let textureName: String?
    let modelName: String?
    let orbit: CelestialOrbit?
    let parentBodyId: String?
    let displayOrder: Int
    let tags: [String]
}

struct CelestialOrbit: Codable, Equatable {
    static let j2000JulianDay = 2_451_545.0

    let semiMajorAxisKm: Double
    let eccentricity: Double
    let inclinationDegrees: Double
    let longitudeOfAscendingNodeDegrees: Double
    let argumentOfPeriapsisDegrees: Double
    let meanAnomalyAtEpochDegrees: Double
    let epochJulianDay: Double?

    var effectiveEpochJulianDay: Double {
        epochJulianDay ?? Self.j2000JulianDay
    }

    init(
        semiMajorAxisKm: Double,
        eccentricity: Double,
        inclinationDegrees: Double,
        longitudeOfAscendingNodeDegrees: Double,
        argumentOfPeriapsisDegrees: Double,
        meanAnomalyAtEpochDegrees: Double,
        epochJulianDay: Double? = nil
    ) {
        self.semiMajorAxisKm = semiMajorAxisKm
        self.eccentricity = eccentricity
        self.inclinationDegrees = inclinationDegrees
        self.longitudeOfAscendingNodeDegrees = longitudeOfAscendingNodeDegrees
        self.argumentOfPeriapsisDegrees = argumentOfPeriapsisDegrees
        self.meanAnomalyAtEpochDegrees = meanAnomalyAtEpochDegrees
        self.epochJulianDay = epochJulianDay
    }
}

enum CelestialBodyType: String, Codable, CaseIterable, Identifiable {
    case star
    case planet
    case moon
    case satellite
    case rocket
    case spacecraft
    case station
    case astronaut
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
        case .rocket:
            return "Rocket"
        case .spacecraft:
            return "Spacecraft"
        case .station:
            return "Station"
        case .astronaut:
            return "Astronaut"
        case .asteroid:
            return "Asteroid"
        case .dwarfPlanet:
            return "Dwarf Planet"
        }
    }
}
