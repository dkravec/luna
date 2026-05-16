import Foundation

struct ExperienceSceneSettings: Equatable {
    var isAREnabled: Bool
    var distanceScaleMode: DistanceScaleMode
    var objectScaleMode: ObjectScaleMode
    var distanceCompression: Double
    var orbitPlaybackSpeed: OrbitPlaybackSpeed
    var showLabels: Bool
    var showOrbits: Bool

    static let defaults = ExperienceSceneSettings(
        isAREnabled: false,
        distanceScaleMode: .educational,
        objectScaleMode: .relative,
        distanceCompression: 30,
        orbitPlaybackSpeed: .standard,
        showLabels: true,
        showOrbits: true
    )

    init(isAREnabled: Bool, preferences: ExperiencePreferences) {
        self.init(
            isAREnabled: isAREnabled,
            distanceScaleMode: preferences.distanceScaleMode,
            objectScaleMode: preferences.objectScaleMode,
            distanceCompression: preferences.distanceCompression,
            orbitPlaybackSpeed: preferences.orbitPlaybackSpeed,
            showLabels: preferences.showLabels,
            showOrbits: preferences.showOrbits
        )
    }

    init(
        isAREnabled: Bool,
        distanceScaleMode: DistanceScaleMode,
        objectScaleMode: ObjectScaleMode,
        distanceCompression: Double,
        orbitPlaybackSpeed: OrbitPlaybackSpeed,
        showLabels: Bool,
        showOrbits: Bool
    ) {
        self.isAREnabled = isAREnabled
        self.distanceScaleMode = distanceScaleMode
        self.objectScaleMode = objectScaleMode
        self.distanceCompression = distanceCompression
        self.orbitPlaybackSpeed = orbitPlaybackSpeed
        self.showLabels = showLabels
        self.showOrbits = showOrbits
    }
}
