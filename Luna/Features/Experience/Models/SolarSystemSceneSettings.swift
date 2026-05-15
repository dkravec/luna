import Foundation

struct SolarSystemSceneSettings: Equatable {
    var isAREnabled: Bool
    var scaleMode: ScaleMode
    var distanceCompression: Double
    var planetSizeMultiplier: Double
    var showLabels: Bool
    var showOrbits: Bool

    static let defaults = SolarSystemSceneSettings(
        isAREnabled: true,
        scaleMode: .educational,
        distanceCompression: 30,
        planetSizeMultiplier: 1,
        showLabels: true,
        showOrbits: true
    )
}
