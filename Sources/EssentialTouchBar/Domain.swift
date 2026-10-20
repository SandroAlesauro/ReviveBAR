import AppKit
import Foundation

enum EssentialModule: String, Codable, CaseIterable {
    case quickNote
    case clipboard
    case focus

    var title: String {
        switch self {
        case .quickNote:
            return "Quick Note"
        case .clipboard:
            return "Clipboard"
        case .focus:
            return "Focus"
        }
    }

    var itemIdentifier: NSTouchBarItem.Identifier {
        NSTouchBarItem.Identifier("com.revivebar.module.\(rawValue)")
    }
}

struct TouchBarProfile: Codable, Equatable {
    let id: String
    var name: String
    var modules: [EssentialModule]
}

struct QuickNoteEntry: Codable, Equatable {
    let text: String
    let createdAt: Date
}

enum ReviveBARError: Error, LocalizedError {
    case noClipboardText
    case emptyQuickNote
    case invalidProfileSelection

    var errorDescription: String? {
        switch self {
        case .noClipboardText:
            return "No text found in the clipboard."
        case .emptyQuickNote:
            return "The quick note cannot be empty."
        case .invalidProfileSelection:
            return "Invalid profile selection."
        }
    }
}
