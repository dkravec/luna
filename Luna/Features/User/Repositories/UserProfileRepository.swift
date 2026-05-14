import Foundation

protocol UserProfileRepository {
    func fetchOrCreateProfile() throws -> UserProfile
    func save(_ profile: UserProfile) throws
    func resetOnboarding() throws -> UserProfile
    func resetProfile() throws -> UserProfile
}
