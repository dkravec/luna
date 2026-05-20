import CoreData
import Foundation

final class CoreDataUserProfileRepository: UserProfileRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = LunaPersistenceController.shared.container.viewContext) {
        self.context = context
    }

    func fetchOrCreateProfile() throws -> UserProfile {
        if let object = try fetchProfileObject() {
            return UserProfile(managedObject: object)
        }

        let profile = UserProfile.defaultProfile
        let object = UserProfileRecord(context: context)
        object.apply(profile)
        try saveContextIfNeeded()
        return profile
    }

    func save(_ profile: UserProfile) throws {
        let object = try fetchProfileObject() ?? UserProfileRecord(context: context)
        object.apply(profile)
        try saveContextIfNeeded()
    }

    func resetOnboarding() throws -> UserProfile {
        var profile = try fetchOrCreateProfile()
        profile.hasCompletedOnboarding = false
        try save(profile)
        return profile
    }

    func resetProfile() throws -> UserProfile {
        let profile = UserProfile.defaultProfile
        let object = try fetchProfileObject() ?? UserProfileRecord(context: context)
        object.apply(profile)
        try saveContextIfNeeded()
        return profile
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

extension UserProfile {
    init(managedObject: UserProfileRecord) {
        let appearance = AppAppearancePreference(rawValue: managedObject.appearancePreferenceRaw ?? "") ?? .system
        let hapticIntensity = HapticIntensity(rawValue: managedObject.hapticIntensityRaw ?? "") ?? .heavy

        self.init(
            id: managedObject.id ?? UUID(),
            displayName: managedObject.displayName,
            hasCompletedOnboarding: managedObject.hasCompletedOnboarding,
            hasCompletedFirstRunTour: managedObject.hasCompletedFirstRunTour,
            appearancePreference: appearance,
            hapticsEnabled: managedObject.hapticsEnabled,
            hapticIntensity: hapticIntensity
        )
    }
}

@objc(UserProfileRecord)
final class UserProfileRecord: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var displayName: String?
    @NSManaged var hasCompletedOnboarding: Bool
    @NSManaged var hasCompletedFirstRunTour: Bool
    @NSManaged var preferredScaleModeRaw: String?
    @NSManaged var distanceCompression: Double
    @NSManaged var planetSizeMultiplier: Double
    @NSManaged var prefersARMode: Bool
    @NSManaged var appearancePreferenceRaw: String?
    @NSManaged var showLabels: Bool
    @NSManaged var showOrbits: Bool
    @NSManaged var hapticsEnabled: Bool
    @NSManaged var hapticIntensityRaw: String?
}

extension UserProfileRecord {
    @nonobjc
    class func fetchRequest() -> NSFetchRequest<UserProfileRecord> {
        NSFetchRequest<UserProfileRecord>(entityName: "UserProfileRecord")
    }

    func apply(_ profile: UserProfile) {
        id = profile.id
        displayName = profile.displayName
        hasCompletedOnboarding = profile.hasCompletedOnboarding
        hasCompletedFirstRunTour = profile.hasCompletedFirstRunTour
        appearancePreferenceRaw = profile.appearancePreference.rawValue
        hapticsEnabled = profile.hapticsEnabled
        hapticIntensityRaw = profile.hapticIntensity.rawValue
    }
}
