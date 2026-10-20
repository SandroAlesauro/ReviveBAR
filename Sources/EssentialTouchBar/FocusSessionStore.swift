import Foundation

final class FocusSessionStore {
    private let activeUntilKey = "revivebar.focus.activeUntil"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func startSession(minutes: Int) {
        let endDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        userDefaults.set(endDate.timeIntervalSince1970, forKey: activeUntilKey)
    }

    func stopSession() {
        userDefaults.removeObject(forKey: activeUntilKey)
    }

    func activeUntil() -> Date? {
        let timestamp = userDefaults.double(forKey: activeUntilKey)
        guard timestamp > 0 else {
            return nil
        }
        let date = Date(timeIntervalSince1970: timestamp)
        if date > Date() {
            return date
        }
        userDefaults.removeObject(forKey: activeUntilKey)
        return nil
    }

    func remainingTime() -> TimeInterval? {
        guard let activeUntilDate = activeUntil() else {
            return nil
        }
        return activeUntilDate.timeIntervalSinceNow
    }
}
