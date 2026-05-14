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
            attribute("preferredScaleModeRaw", type: .stringAttributeType, optional: false, defaultValue: ScaleMode.educational.rawValue),
            attribute("prefersARMode", type: .booleanAttributeType, optional: false, defaultValue: true),
            attribute("appearancePreferenceRaw", type: .stringAttributeType, optional: false, defaultValue: AppAppearancePreference.system.rawValue),
            attribute("showLabels", type: .booleanAttributeType, optional: false, defaultValue: true),
            attribute("showOrbits", type: .booleanAttributeType, optional: false, defaultValue: true)
        ]

        model.entities = [profileEntity]
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
