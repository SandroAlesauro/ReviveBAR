import AppKit
import Foundation

final class ClipboardStackStore {
    private let entriesKey = "revivebar.clipboard.entries"
    private let maxEntries = 20
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func entries() throws -> [String] {
        guard let data = userDefaults.data(forKey: entriesKey) else {
            return []
        }
        return try JSONDecoder().decode([String].self, from: data)
    }

    @discardableResult
    func captureCurrentClipboard() throws -> [String] {
        let pasteboard = NSPasteboard.general
        guard let content = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            throw ReviveBARError.noClipboardText
        }
        var currentEntries = try entries()
        if currentEntries.first != content {
            currentEntries.insert(content, at: 0)
        }
        if currentEntries.count > maxEntries {
            currentEntries = Array(currentEntries.prefix(maxEntries))
        }
        let data = try JSONEncoder().encode(currentEntries)
        userDefaults.set(data, forKey: entriesKey)
        return currentEntries
    }
}
