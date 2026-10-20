import Foundation

final class CustomActionStore {
    private let actionsByProfileKey = "revivebar.custom.actions.byProfile"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func actions(for profileID: String) throws -> [CustomTouchBarAction] {
        let allActions = try actionsByProfile()
        return allActions[profileID] ?? []
    }

    @discardableResult
    func addAction(
        profileID: String,
        title: String,
        payload: String
    ) throws -> [CustomTouchBarAction] {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else {
            throw ReviveBARError.emptyCustomActionTitle
        }

        let normalizedPayload = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPayload.isEmpty else {
            throw ReviveBARError.emptyCustomActionPayload
        }

        var allActions = try actionsByProfile()
        var profileActions = allActions[profileID] ?? []
        let action = CustomTouchBarAction(
            id: UUID().uuidString,
            title: normalizedTitle,
            payload: normalizedPayload,
            createdAt: Date()
        )
        profileActions.insert(action, at: 0)
        allActions[profileID] = profileActions
        try save(actionsByProfile: allActions)
        return profileActions
    }

    @discardableResult
    func deleteAction(
        profileID: String,
        actionID: String
    ) throws -> [CustomTouchBarAction] {
        var allActions = try actionsByProfile()
        var profileActions = allActions[profileID] ?? []
        profileActions.removeAll(where: { $0.id == actionID })
        allActions[profileID] = profileActions
        try save(actionsByProfile: allActions)
        return profileActions
    }

    private func actionsByProfile() throws -> [String: [CustomTouchBarAction]] {
        guard let data = userDefaults.data(forKey: actionsByProfileKey) else {
            return [:]
        }
        return try JSONDecoder().decode([String: [CustomTouchBarAction]].self, from: data)
    }

    private func save(actionsByProfile: [String: [CustomTouchBarAction]]) throws {
        let encoded = try JSONEncoder().encode(actionsByProfile)
        userDefaults.set(encoded, forKey: actionsByProfileKey)
    }
}
