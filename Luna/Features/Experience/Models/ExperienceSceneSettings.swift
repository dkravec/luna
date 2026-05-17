import Foundation

struct ExperienceSceneSettings: Equatable {
    static let minimumDistanceCompression: Double = 2
    static let maximumDistanceCompression: Double = 50

    var isAREnabled: Bool
    var distanceScaleMode: DistanceScaleMode
    var objectScaleMode: ObjectScaleMode
    var distanceCompression: Double
    var orbitPlaybackSpeed: OrbitPlaybackSpeed
    var objectRotationSpeed: ObjectRotationSpeed
    var showLabels: Bool
    var showOrbits: Bool

    static let defaults = ExperienceSceneSettings(
        isAREnabled: false,
        distanceScaleMode: .educational,
        objectScaleMode: .relative,
        distanceCompression: 30,
        orbitPlaybackSpeed: .standard,
        objectRotationSpeed: .slow,
        showLabels: true,
        showOrbits: true
    )

    static func clampedDistanceCompression(_ value: Double) -> Double {
        min(max(value, minimumDistanceCompression), maximumDistanceCompression)
    }

    init(isAREnabled: Bool, preferences: ExperiencePreferences) {
        self.init(
            isAREnabled: isAREnabled,
            distanceScaleMode: preferences.distanceScaleMode,
            objectScaleMode: preferences.objectScaleMode,
            distanceCompression: preferences.distanceCompression,
            orbitPlaybackSpeed: preferences.orbitPlaybackSpeed,
            objectRotationSpeed: preferences.objectRotationSpeed,
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
        objectRotationSpeed: ObjectRotationSpeed,
        showLabels: Bool,
        showOrbits: Bool
    ) {
        self.isAREnabled = isAREnabled
        self.distanceScaleMode = distanceScaleMode
        self.objectScaleMode = objectScaleMode
        self.distanceCompression = Self.clampedDistanceCompression(distanceCompression)
        self.orbitPlaybackSpeed = orbitPlaybackSpeed
        self.objectRotationSpeed = objectRotationSpeed
        self.showLabels = showLabels
        self.showOrbits = showOrbits
    }
}
