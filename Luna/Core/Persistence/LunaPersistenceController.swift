import CoreData

final class LunaPersistenceController {
    static let shared = LunaPersistenceController()

    let container: NSPersistentContainer

    private init(inMemory: Bool = false) {
        let model = NSManagedObjectModel()
        container = NSPersistentContainer(name: "Luna", managedObjectModel: model)

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
    }
}
