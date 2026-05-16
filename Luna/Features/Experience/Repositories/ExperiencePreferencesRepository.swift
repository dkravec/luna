import Foundation

protocol ExperiencePreferencesRepository {
    func fetchOrCreatePreferences() throws -> ExperiencePreferences
    func save(_ preferences: ExperiencePreferences) throws
    func resetPreferences() throws -> ExperiencePreferences
}
