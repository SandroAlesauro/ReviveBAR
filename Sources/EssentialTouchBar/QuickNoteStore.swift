import Foundation

final class QuickNoteStore {
    private let fileURL: URL

    init(fileManager: FileManager = .default) throws {
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let appDirectoryURL = appSupportURL.appendingPathComponent("ReviveBAR", isDirectory: true)
        if !fileManager.fileExists(atPath: appDirectoryURL.path) {
            try fileManager.createDirectory(at: appDirectoryURL, withIntermediateDirectories: true)
        }
        fileURL = appDirectoryURL.appendingPathComponent("quick-notes.json")
    }

    func allNotes() throws -> [QuickNoteEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([QuickNoteEntry].self, from: data)
    }

    @discardableResult
    func add(note text: String) throws -> QuickNoteEntry {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else {
            throw ReviveBARError.emptyQuickNote
        }
        var notes = try allNotes()
        let entry = QuickNoteEntry(text: normalizedText, createdAt: Date())
        notes.insert(entry, at: 0)
        let data = try JSONEncoder().encode(notes)
        try data.write(to: fileURL, options: .atomic)
        return entry
    }
}
