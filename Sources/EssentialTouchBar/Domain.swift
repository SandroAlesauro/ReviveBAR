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

    var subtitle: String {
        switch self {
        case .quickNote:
            return "Capture thoughts instantly."
        case .clipboard:
            return "Save your latest copied text."
        case .focus:
            return "Run a 25-minute focus sprint."
        }
    }

    var symbolName: String {
        switch self {
        case .quickNote:
            return "square.and.pencil"
        case .clipboard:
            return "doc.on.doc"
        case .focus:
            return "timer"
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

struct CustomTouchBarAction: Codable, Equatable {
    let id: String
    let title: String
    let payload: String
    let createdAt: Date
}

enum ReviveBARError: Error, LocalizedError {
    case noClipboardText
    case emptyQuickNote
    case invalidProfileSelection
    case emptyCustomActionTitle
    case emptyCustomActionPayload

    var errorDescription: String? {
        switch self {
        case .noClipboardText:
            return "No text found in the clipboard."
        case .emptyQuickNote:
            return "The quick note cannot be empty."
        case .invalidProfileSelection:
            return "Invalid profile selection."
        case .emptyCustomActionTitle:
            return "Custom button title cannot be empty."
        case .emptyCustomActionPayload:
            return "Custom button payload cannot be empty."
        }
    }
}
