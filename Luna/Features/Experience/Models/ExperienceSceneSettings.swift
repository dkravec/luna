import Foundation

struct ExperienceSceneSettings: Equatable {
    static let minimumDistanceCompression: Double = 2
    static let maximumDistanceCompression: Double = 50

    var isAREnabled: Bool
    var sceneScaleProfile: SceneScaleProfile
    var distanceScaleMode: DistanceScaleMode
    var objectScaleMode: ObjectScaleMode
    var distanceCompression: Double
    var renderDetail: SceneRenderDetail
    var orbitPlaybackSpeed: OrbitPlaybackSpeed
    var objectRotationSpeed: ObjectRotationSpeed
    var showLabels: Bool
    var showOrbits: Bool

    static let defaults = ExperienceSceneSettings(
        isAREnabled: false,
        sceneScaleProfile: .scaledRecommended,
        distanceScaleMode: .compressed,
        objectScaleMode: .relative,
        distanceCompression: 30,
        renderDetail: .balanced,
        orbitPlaybackSpeed: .standard,
        objectRotationSpeed: .slow,
        showLabels: true,
        showOrbits: true
    )

    static func clampedDistanceCompression(_ value: Double) -> Double {
        min(max(value, minimumDistanceCompression), maximumDistanceCompression)
    }

    init(
        isAREnabled: Bool,
        preferences: ExperiencePreferences,
        sceneScaleProfileOverride: SceneScaleProfile? = nil
    ) {
        let sceneScaleProfile = sceneScaleProfileOverride ?? preferences.sceneScaleProfile
        let usesOverride = sceneScaleProfileOverride != nil

        self.init(
            isAREnabled: isAREnabled,
            sceneScaleProfile: sceneScaleProfile,
            distanceScaleMode: usesOverride ? sceneScaleProfile.defaultDistanceScaleMode : preferences.distanceScaleMode,
            objectScaleMode: usesOverride ? sceneScaleProfile.defaultObjectScaleMode : preferences.objectScaleMode,
            distanceCompression: preferences.distanceCompression,
            renderDetail: preferences.renderDetail,
            orbitPlaybackSpeed: preferences.orbitPlaybackSpeed,
            objectRotationSpeed: preferences.objectRotationSpeed,
            showLabels: preferences.showLabels,
            showOrbits: preferences.showOrbits
        )
    }

    init(
        isAREnabled: Bool,
        sceneScaleProfile: SceneScaleProfile = .custom,
        distanceScaleMode: DistanceScaleMode,
        objectScaleMode: ObjectScaleMode,
        distanceCompression: Double,
        renderDetail: SceneRenderDetail = .balanced,
        orbitPlaybackSpeed: OrbitPlaybackSpeed,
        objectRotationSpeed: ObjectRotationSpeed,
        showLabels: Bool,
        showOrbits: Bool
    ) {
        self.isAREnabled = isAREnabled
        self.sceneScaleProfile = sceneScaleProfile
        self.distanceScaleMode = distanceScaleMode
        self.objectScaleMode = objectScaleMode
        self.distanceCompression = Self.clampedDistanceCompression(distanceCompression)
        self.renderDetail = renderDetail
        self.orbitPlaybackSpeed = orbitPlaybackSpeed
        self.objectRotationSpeed = objectRotationSpeed
        self.showLabels = showLabels
        self.showOrbits = showOrbits
    }
}
