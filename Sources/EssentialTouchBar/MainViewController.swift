import AppKit

final class MainViewController: NSViewController, NSTouchBarDelegate {
    private let statusLabel = NSTextField(labelWithString: "ReviveBAR is ready.")
    private let profilePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let rotateLayoutButton = NSButton(title: "Rotate layout", target: nil, action: nil)
    private let profileStore = ProfileStore()
    private let clipboardStore = ClipboardStackStore()
    private let focusStore = FocusSessionStore()
    private let quickNoteStore: QuickNoteStore
    private var currentProfile: TouchBarProfile?
    private var refreshTimer: Timer?

    init() {
        do {
            self.quickNoteStore = try QuickNoteStore()
        } catch {
            fatalError("Impossibile inizializzare QuickNoteStore: \(error)")
        }
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
        loadProfiles()
        startStatusRefreshTimer()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    private func setupLayout() {
        profilePopup.target = self
        profilePopup.action = #selector(handleProfileChange(_:))
        profilePopup.translatesAutoresizingMaskIntoConstraints = false

        rotateLayoutButton.target = self
        rotateLayoutButton.action = #selector(handleRotateLayout(_:))
        rotateLayoutButton.bezelStyle = .rounded
        rotateLayoutButton.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = .systemFont(ofSize: 18, weight: .medium)
        statusLabel.alignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "ReviveBAR")
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(statusLabel)
        view.addSubview(profilePopup)
        view.addSubview(rotateLayoutButton)
        view.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            profilePopup.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            profilePopup.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            rotateLayoutButton.topAnchor.constraint(equalTo: profilePopup.bottomAnchor, constant: 16),
            rotateLayoutButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: rotateLayoutButton.bottomAnchor, constant: 30)
        ])
    }

    private func loadProfiles() {
        do {
            let profiles = try profileStore.allProfiles()
            profilePopup.removeAllItems()
            profilePopup.addItems(withTitles: profiles.map(\.name))
            let selected = try profileStore.selectedProfile()
            currentProfile = selected
            if let selectedIndex = profiles.firstIndex(where: { $0.id == selected.id }) {
                profilePopup.selectItem(at: selectedIndex)
            }
            reloadTouchBar()
            updateStatus("Profile \(selected.name) loaded.")
        } catch {
            updateStatus("Profile error: \(error.localizedDescription)")
        }
    }

    private func reloadTouchBar() {
        touchBar = makeTouchBar()
    }

    override func makeTouchBar() -> NSTouchBar? {
        guard let profile = currentProfile else {
            return nil
        }
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        var identifiers: [NSTouchBarItem.Identifier] = []
        for (index, module) in profile.modules.enumerated() {
            identifiers.append(module.itemIdentifier)
            if index != profile.modules.count - 1 {
                identifiers.append(.flexibleSpace)
            }
        }
        touchBar.defaultItemIdentifiers = identifiers
        return touchBar
    }

    func touchBar(
        _ touchBar: NSTouchBar,
        makeItemForIdentifier identifier: NSTouchBarItem.Identifier
    ) -> NSTouchBarItem? {
        guard let module = EssentialModule.allCases.first(where: { $0.itemIdentifier == identifier }) else {
            return nil
        }
        let item = NSCustomTouchBarItem(identifier: identifier)
        let button = NSButton(title: module.title, target: self, action: #selector(handleTouchBarAction(_:)))
        button.bezelColor = .controlAccentColor
        button.identifier = NSUserInterfaceItemIdentifier(module.rawValue)
        item.view = button
        return item
    }

    @objc
    private func handleTouchBarAction(_ sender: NSButton) {
        guard let rawIdentifier = sender.identifier?.rawValue else {
            return
        }

        switch rawIdentifier {
        case EssentialModule.quickNote.rawValue:
            openQuickNoteComposer()
        case EssentialModule.clipboard.rawValue:
            captureClipboard()
        case EssentialModule.focus.rawValue:
            toggleFocusSession()
        default:
            updateStatus("Unknown action.")
        }
    }

    @objc
    private func handleProfileChange(_ sender: NSPopUpButton) {
        do {
            let profiles = try profileStore.allProfiles()
            guard sender.indexOfSelectedItem >= 0, sender.indexOfSelectedItem < profiles.count else {
                throw ReviveBARError.invalidProfileSelection
            }
            let selectedProfile = profiles[sender.indexOfSelectedItem]
            try profileStore.setSelectedProfile(id: selectedProfile.id)
            currentProfile = selectedProfile
            reloadTouchBar()
            updateStatus("Profile \(selectedProfile.name) active.")
        } catch {
            updateStatus("Profile switch error: \(error.localizedDescription)")
        }
    }

    @objc
    private func handleRotateLayout(_ sender: NSButton) {
        do {
            guard var profile = currentProfile else {
                throw ReviveBARError.invalidProfileSelection
            }
            guard let first = profile.modules.first else {
                updateStatus("Layout is empty.")
                return
            }
            profile.modules.removeFirst()
            profile.modules.append(first)
            try profileStore.updateProfile(profile)
            currentProfile = profile
            reloadTouchBar()
            updateStatus("Layout for profile \(profile.name) updated.")
        } catch {
            updateStatus("Layout save error: \(error.localizedDescription)")
        }
    }

    private func openQuickNoteComposer() {
        let alert = NSAlert()
        alert.messageText = "New Quick Note"
        alert.informativeText = "Write a quick note."
        alert.alertStyle = .informational
        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        inputField.placeholderString = "Type here..."
        alert.accessoryView = inputField
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            updateStatus("Quick note canceled.")
            return
        }

        do {
            let entry = try quickNoteStore.add(note: inputField.stringValue)
            let notes = try quickNoteStore.allNotes()
            updateStatus("Saved note: \(entry.text). Total notes: \(notes.count).")
        } catch {
            updateStatus("Quick note error: \(error.localizedDescription)")
        }
    }

    private func captureClipboard() {
        do {
            let entries = try clipboardStore.captureCurrentClipboard()
            guard let first = entries.first else {
                updateStatus("Clipboard is empty.")
                return
            }
            updateStatus("Clipboard updated (\(entries.count)): \(first)")
        } catch {
            updateStatus("Clipboard error: \(error.localizedDescription)")
        }
    }

    private func toggleFocusSession() {
        if focusStore.activeUntil() != nil {
            focusStore.stopSession()
            updateStatus("Focus stopped.")
        } else {
            focusStore.startSession(minutes: 25)
            updateFocusStatus()
        }
    }

    private func startStatusRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(handleStatusRefreshTick),
            userInfo: nil,
            repeats: true
        )
    }

    @objc
    private func handleStatusRefreshTick() {
        updateFocusStatus()
    }

    private func updateFocusStatus() {
        guard let remaining = focusStore.remainingTime() else {
            return
        }
        let totalSeconds = Int(remaining)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        updateStatus("Focus active: \(String(format: "%02d:%02d", minutes, seconds))")
    }

    private func updateStatus(_ text: String) {
        statusLabel.stringValue = text
    }
}
