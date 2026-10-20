import AppKit

final class MainViewController: NSViewController, NSTouchBarDelegate {
    private let profileControl = NSSegmentedControl(labels: [], trackingMode: .selectOne, target: nil, action: nil)
    private let rotateLayoutButton = NSButton(title: "Rotate layout", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "ReviveBAR is ready.")
    private let moduleStack = NSStackView()

    private let profileStore = ProfileStore()
    private let clipboardStore = ClipboardStackStore()
    private let focusStore = FocusSessionStore()
    private let quickNoteStore: QuickNoteStore

    private var profiles: [TouchBarProfile] = []
    private var currentProfile: TouchBarProfile?
    private var refreshTimer: Timer?

    init() {
        do {
            self.quickNoteStore = try QuickNoteStore()
        } catch {
            fatalError("Unable to initialize QuickNoteStore: \(error)")
        }
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let rootView = NSView()
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        view = rootView
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

    private func setupLayout() {
        let shellView = NSVisualEffectView()
        shellView.material = .hudWindow
        shellView.blendingMode = .behindWindow
        shellView.state = .active
        shellView.wantsLayer = true
        shellView.layer?.cornerRadius = 18
        shellView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.30).cgColor
        shellView.layer?.borderWidth = 1
        shellView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(shellView)

        let titleLabel = NSTextField(labelWithString: "ReviveBAR")
        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)

        let subtitleLabel = NSTextField(labelWithString: "Apple-native UI with Nothing-style essential actions.")
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor

        let headingStack = NSStackView(views: [titleLabel, subtitleLabel])
        headingStack.orientation = .vertical
        headingStack.alignment = .leading
        headingStack.spacing = 6

        profileControl.segmentStyle = .rounded
        profileControl.target = self
        profileControl.action = #selector(handleProfileChange(_:))

        rotateLayoutButton.bezelStyle = .rounded
        rotateLayoutButton.target = self
        rotateLayoutButton.action = #selector(handleRotateLayout(_:))

        let controlRow = NSStackView(views: [profileControl, rotateLayoutButton])
        controlRow.orientation = .horizontal
        controlRow.alignment = .centerY
        controlRow.spacing = 12

        let modulesTitle = NSTextField(labelWithString: "Essential apps")
        modulesTitle.font = .systemFont(ofSize: 14, weight: .semibold)

        moduleStack.orientation = .vertical
        moduleStack.alignment = .leading
        moduleStack.spacing = 10
        moduleStack.translatesAutoresizingMaskIntoConstraints = false

        let statusContainer = NSVisualEffectView()
        statusContainer.material = .menu
        statusContainer.blendingMode = .withinWindow
        statusContainer.state = .active
        statusContainer.wantsLayer = true
        statusContainer.layer?.cornerRadius = 10
        statusContainer.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusContainer.addSubview(statusLabel)

        let rootStack = NSStackView(views: [headingStack, controlRow, modulesTitle, moduleStack, statusContainer])
        rootStack.orientation = .vertical
        rootStack.alignment = .leading
        rootStack.spacing = 18
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        shellView.addSubview(rootStack)

        NSLayoutConstraint.activate([
            shellView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            shellView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            shellView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            shellView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),

            rootStack.topAnchor.constraint(equalTo: shellView.topAnchor, constant: 24),
            rootStack.leadingAnchor.constraint(equalTo: shellView.leadingAnchor, constant: 24),
            rootStack.trailingAnchor.constraint(equalTo: shellView.trailingAnchor, constant: -24),
            rootStack.bottomAnchor.constraint(lessThanOrEqualTo: shellView.bottomAnchor, constant: -24),

            statusContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 360),
            statusLabel.topAnchor.constraint(equalTo: statusContainer.topAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: statusContainer.leadingAnchor, constant: 10),
            statusLabel.trailingAnchor.constraint(equalTo: statusContainer.trailingAnchor, constant: -10),
            statusLabel.bottomAnchor.constraint(equalTo: statusContainer.bottomAnchor, constant: -8)
        ])
    }

    private func loadProfiles() {
        do {
            profiles = try profileStore.allProfiles()
            configureProfileControl(with: profiles)

            let selected = try profileStore.selectedProfile()
            currentProfile = selected

            if let selectedIndex = profiles.firstIndex(where: { $0.id == selected.id }) {
                profileControl.selectedSegment = selectedIndex
            }

            renderModuleCards()
            reloadTouchBar()
            updateStatus("Profile \(selected.name) loaded.")
        } catch {
            updateStatus("Profile error: \(error.localizedDescription)")
        }
    }

    private func configureProfileControl(with profiles: [TouchBarProfile]) {
        profileControl.segmentCount = profiles.count
        for (index, profile) in profiles.enumerated() {
            profileControl.setLabel(profile.name, forSegment: index)
        }
    }

    private func renderModuleCards() {
        moduleStack.arrangedSubviews.forEach { view in
            moduleStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        guard let profile = currentProfile else {
            return
        }

        for module in profile.modules {
            let card = ModuleCardView(module: module, actionTitle: actionTitle(for: module)) { [weak self] in
                self?.perform(module)
            }
            card.widthAnchor.constraint(equalToConstant: 620).isActive = true
            moduleStack.addArrangedSubview(card)
        }
    }

    private func actionTitle(for module: EssentialModule) -> String {
        switch module {
        case .quickNote:
            return "Add"
        case .clipboard:
            return "Capture"
        case .focus:
            return focusStore.activeUntil() == nil ? "Start" : "Stop"
        }
    }

    private func perform(_ module: EssentialModule) {
        switch module {
        case .quickNote:
            openQuickNoteComposer()
        case .clipboard:
            captureClipboard()
        case .focus:
            toggleFocusSession()
        }
    }

    private func reloadTouchBar() {
        touchBar = makeTouchBar()
    }

    @objc
    private func handleTouchBarAction(_ sender: NSButton) {
        guard let rawIdentifier = sender.identifier?.rawValue,
              let module = EssentialModule(rawValue: rawIdentifier) else {
            updateStatus("Unknown action.")
            return
        }
        perform(module)
    }

    @objc
    private func handleProfileChange(_ sender: NSSegmentedControl) {
        do {
            guard sender.selectedSegment >= 0, sender.selectedSegment < profiles.count else {
                throw ReviveBARError.invalidProfileSelection
            }
            let selectedProfile = profiles[sender.selectedSegment]
            try profileStore.setSelectedProfile(id: selectedProfile.id)
            currentProfile = selectedProfile
            renderModuleCards()
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

            if let profileIndex = profiles.firstIndex(where: { $0.id == profile.id }) {
                profiles[profileIndex] = profile
            }
            currentProfile = profile
            renderModuleCards()
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
        renderModuleCards()
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
