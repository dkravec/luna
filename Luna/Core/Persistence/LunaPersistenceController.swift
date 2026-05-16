import CoreData

final class LunaPersistenceController {
    static let shared = LunaPersistenceController()
    static let preview = LunaPersistenceController(inMemory: true)

    let container: NSPersistentContainer

    private init(inMemory: Bool = false) {
        let model = Self.makeManagedObjectModel()
        container = NSPersistentContainer(name: "Luna", managedObjectModel: model)

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.persistentStoreDescriptions.forEach { description in
            description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true

        container.loadPersistentStores { _, error in
            if let error {
                assertionFailure("Unable to load Luna persistent store: \(error)")
            }
        }
    }

    private static func makeManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let profileEntity = NSEntityDescription()
        profileEntity.name = "UserProfileRecord"
        profileEntity.managedObjectClassName = NSStringFromClass(UserProfileRecord.self)
        profileEntity.properties = [
            attribute("id", type: .UUIDAttributeType, optional: false),
            attribute("displayName", type: .stringAttributeType, optional: true),
            attribute("hasCompletedOnboarding", type: .booleanAttributeType, optional: false, defaultValue: false),
            attribute("preferredScaleModeRaw", type: .stringAttributeType, optional: false, defaultValue: DistanceScaleMode.educational.rawValue),
            attribute("distanceCompression", type: .doubleAttributeType, optional: false, defaultValue: 30),
            attribute("planetSizeMultiplier", type: .doubleAttributeType, optional: false, defaultValue: 5),
            attribute("prefersARMode", type: .booleanAttributeType, optional: false, defaultValue: true),
            attribute("appearancePreferenceRaw", type: .stringAttributeType, optional: false, defaultValue: AppAppearancePreference.system.rawValue),
            attribute("showLabels", type: .booleanAttributeType, optional: false, defaultValue: true),
            attribute("showOrbits", type: .booleanAttributeType, optional: false, defaultValue: true),
            attribute("hapticsEnabled", type: .booleanAttributeType, optional: false, defaultValue: true),
            attribute("hapticIntensityRaw", type: .stringAttributeType, optional: false, defaultValue: HapticIntensity.heavy.rawValue)
        ]

        let experienceEntity = NSEntityDescription()
        experienceEntity.name = "ExperiencePreferencesRecord"
        experienceEntity.managedObjectClassName = NSStringFromClass(ExperiencePreferencesRecord.self)
        experienceEntity.properties = [
            attribute("id", type: .UUIDAttributeType, optional: false),
            attribute("prefersARMode", type: .booleanAttributeType, optional: false, defaultValue: true),
            attribute("distanceScaleModeRaw", type: .stringAttributeType, optional: false, defaultValue: DistanceScaleMode.educational.rawValue),
            attribute("objectScaleModeRaw", type: .stringAttributeType, optional: false, defaultValue: ObjectScaleMode.relative.rawValue),
            attribute("distanceCompression", type: .doubleAttributeType, optional: false, defaultValue: 30),
            attribute("orbitPlaybackSpeedRaw", type: .stringAttributeType, optional: false, defaultValue: OrbitPlaybackSpeed.standard.rawValue),
            attribute("showLabels", type: .booleanAttributeType, optional: false, defaultValue: true),
            attribute("showOrbits", type: .booleanAttributeType, optional: false, defaultValue: true)
        ]

        model.entities = [profileEntity, experienceEntity]
        return model
    }

    private static func attribute(
        _ name: String,
        type: NSAttributeType,
        optional: Bool,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        attribute.defaultValue = defaultValue
        return attribute
    }
}
