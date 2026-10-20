import Foundation

final class ProfileStore {
    private let profilesKey = "revivebar.profiles"
    private let selectedProfileIDKey = "revivebar.selectedProfileID"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func allProfiles() throws -> [TouchBarProfile] {
        if let data = userDefaults.data(forKey: profilesKey) {
            return try JSONDecoder().decode([TouchBarProfile].self, from: data)
        }
        let defaults = defaultProfiles()
        try saveProfiles(defaults)
        userDefaults.set(defaults[0].id, forKey: selectedProfileIDKey)
        return defaults
    }

    func selectedProfile() throws -> TouchBarProfile {
        let profiles = try allProfiles()
        if let selectedID = userDefaults.string(forKey: selectedProfileIDKey),
           let profile = profiles.first(where: { $0.id == selectedID }) {
            return profile
        }
        guard let firstProfile = profiles.first else {
            throw ReviveBARError.invalidProfileSelection
        }
        userDefaults.set(firstProfile.id, forKey: selectedProfileIDKey)
        return firstProfile
    }

    func setSelectedProfile(id: String) throws {
        let profiles = try allProfiles()
        guard profiles.contains(where: { $0.id == id }) else {
            throw ReviveBARError.invalidProfileSelection
        }
        userDefaults.set(id, forKey: selectedProfileIDKey)
    }

    func updateProfile(_ profile: TouchBarProfile) throws {
        var profiles = try allProfiles()
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else {
            throw ReviveBARError.invalidProfileSelection
        }
        profiles[index] = profile
        try saveProfiles(profiles)
    }

    private func saveProfiles(_ profiles: [TouchBarProfile]) throws {
        let encoded = try JSONEncoder().encode(profiles)
        userDefaults.set(encoded, forKey: profilesKey)
    }

    private func defaultProfiles() -> [TouchBarProfile] {
        [
            TouchBarProfile(
                id: "creator",
                name: "Creator",
                modules: [.quickNote, .clipboard, .focus]
            ),
            TouchBarProfile(
                id: "developer",
                name: "Developer",
                modules: [.clipboard, .focus, .quickNote]
            )
        ]
    }
}
