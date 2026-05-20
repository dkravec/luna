import CoreData
import Foundation

final class CoreDataExperiencePreferencesRepository: ExperiencePreferencesRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = LunaPersistenceController.shared.container.viewContext) {
        self.context = context
    }

    func fetchOrCreatePreferences() throws -> ExperiencePreferences {
        if let object = try fetchPreferencesObject() {
            return ExperiencePreferences(managedObject: object)
        }

        let preferences = try migratedDefaults()
        let object = ExperiencePreferencesRecord(context: context)
        object.apply(preferences)
        try saveContextIfNeeded()
        return preferences
    }

    func save(_ preferences: ExperiencePreferences) throws {
        let object = try fetchPreferencesObject() ?? ExperiencePreferencesRecord(context: context)
        object.apply(preferences)
        try saveContextIfNeeded()
    }

    func resetPreferences() throws -> ExperiencePreferences {
        let preferences = ExperiencePreferences.defaults
        let object = try fetchPreferencesObject() ?? ExperiencePreferencesRecord(context: context)
        object.apply(preferences)
        try saveContextIfNeeded()
        return preferences
    }

    private func migratedDefaults() throws -> ExperiencePreferences {
        guard let profile = try fetchProfileObject() else {
            return .defaults
        }

        var preferences = ExperiencePreferences.defaults
        preferences.prefersARMode = profile.prefersARMode
        let distanceMode = DistanceScaleMode.fromLegacyRawValue(profile.preferredScaleModeRaw)
        preferences.distanceScaleMode = distanceMode == .educational ? .compressed : distanceMode
        preferences.objectScaleMode = .fromLegacyMultiplier(profile.planetSizeMultiplier)
        preferences.sceneScaleProfile = .custom
        preferences.distanceCompression = profile.distanceCompression
        preferences.showLabels = profile.showLabels
        preferences.showOrbits = profile.showOrbits
        return preferences
    }

    private func fetchPreferencesObject() throws -> ExperiencePreferencesRecord? {
        let request = ExperiencePreferencesRecord.fetchRequest()
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func fetchProfileObject() throws -> UserProfileRecord? {
        let request = UserProfileRecord.fetchRequest()
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func saveContextIfNeeded() throws {
        guard context.hasChanges else { return }
        try context.save()
    }
}

extension ExperiencePreferences {
    init(managedObject: ExperiencePreferencesRecord) {
        let profile = SceneScaleProfile(rawValue: managedObject.sceneScaleProfileRaw ?? "") ?? .scaledRecommended
        let distanceMode = DistanceScaleMode(rawValue: managedObject.distanceScaleModeRaw ?? "") ?? profile.defaultDistanceScaleMode
        let objectMode = ObjectScaleMode(rawValue: managedObject.objectScaleModeRaw ?? "") ?? .relative
        let renderDetail = SceneRenderDetail(rawValue: managedObject.renderDetailRaw ?? "") ?? .balanced
        let playbackSpeed = OrbitPlaybackSpeed(rawValue: managedObject.orbitPlaybackSpeedRaw ?? "") ?? .standard
        let rotationSpeed = ObjectRotationSpeed(rawValue: managedObject.objectRotationSpeedRaw ?? "") ?? .slow

        self.init(
            id: managedObject.id ?? UUID(),
            prefersARMode: managedObject.prefersARMode,
            sceneScaleProfile: profile,
            distanceScaleMode: distanceMode,
            objectScaleMode: objectMode,
            distanceCompression: managedObject.distanceCompression,
            renderDetail: renderDetail,
            orbitPlaybackSpeed: playbackSpeed,
            objectRotationSpeed: rotationSpeed,
            showLabels: managedObject.showLabels,
            showOrbits: managedObject.showOrbits
        )
    }
}

@objc(ExperiencePreferencesRecord)
final class ExperiencePreferencesRecord: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var prefersARMode: Bool
    @NSManaged var sceneScaleProfileRaw: String?
    @NSManaged var distanceScaleModeRaw: String?
    @NSManaged var objectScaleModeRaw: String?
    @NSManaged var distanceCompression: Double
    @NSManaged var renderDetailRaw: String?
    @NSManaged var orbitPlaybackSpeedRaw: String?
    @NSManaged var objectRotationSpeedRaw: String?
    @NSManaged var showLabels: Bool
    @NSManaged var showOrbits: Bool
}

extension ExperiencePreferencesRecord {
    @nonobjc
    class func fetchRequest() -> NSFetchRequest<ExperiencePreferencesRecord> {
        NSFetchRequest<ExperiencePreferencesRecord>(entityName: "ExperiencePreferencesRecord")
    }

    func apply(_ preferences: ExperiencePreferences) {
        id = preferences.id
        prefersARMode = preferences.prefersARMode
        sceneScaleProfileRaw = preferences.sceneScaleProfile.rawValue
        distanceScaleModeRaw = preferences.distanceScaleMode.rawValue
        objectScaleModeRaw = preferences.objectScaleMode.rawValue
        distanceCompression = preferences.distanceCompression
        renderDetailRaw = preferences.renderDetail.rawValue
        orbitPlaybackSpeedRaw = preferences.orbitPlaybackSpeed.rawValue
        objectRotationSpeedRaw = preferences.objectRotationSpeed.rawValue
        showLabels = preferences.showLabels
        showOrbits = preferences.showOrbits
    }
}
