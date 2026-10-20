import AppKit

private enum WorkspaceMode: Int {
    case use = 0
    case create = 1
}

final class MainViewController: NSViewController, NSTouchBarDelegate {
    private let profileControl = NSSegmentedControl(labels: [], trackingMode: .selectOne, target: nil, action: nil)
    private let modeControl = NSSegmentedControl(labels: ["Use", "Create"], trackingMode: .selectOne, target: nil, action: nil)
    private let rotateLayoutButton = NSButton(title: "Rotate layout", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "ReviveBAR is ready.")
    private let moduleStack = NSStackView()

    private let createPanel = NSVisualEffectView()
    private let customTitleField = NSTextField()
    private let customPayloadField = NSTextField()
    private let addCustomActionButton = NSButton(title: "Add custom button", target: nil, action: nil)
    private let customActionsStack = NSStackView()

    private let profileStore = ProfileStore()
    private let customActionStore = CustomActionStore()
    private let clipboardStore = ClipboardStackStore()
    private let focusStore = FocusSessionStore()
    private let quickNoteStore: QuickNoteStore

    private var profiles: [TouchBarProfile] = []
    private var currentProfile: TouchBarProfile?
    private var customActions: [CustomTouchBarAction] = []
    private var refreshTimer: Timer?

    private let customIdentifierPrefix = "com.revivebar.custom."

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

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.touchBar = makeTouchBar()
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

        if !customActions.isEmpty {
            if !identifiers.isEmpty {
                identifiers.append(.flexibleSpace)
            }
            identifiers.append(contentsOf: customActions.map { customIdentifier(for: $0) })
        }

        touchBar.defaultItemIdentifiers = identifiers
        return touchBar
    }

    func touchBar(
        _ touchBar: NSTouchBar,
        makeItemForIdentifier identifier: NSTouchBarItem.Identifier
    ) -> NSTouchBarItem? {
        if let module = EssentialModule.allCases.first(where: { $0.itemIdentifier == identifier }) {
            let item = touchBarButtonItem(
                identifier: identifier,
                title: module.title,
                symbolName: module.symbolName
            )
            return item
        }

        if let action = customAction(for: identifier) {
            let item = touchBarButtonItem(
                identifier: identifier,
                title: action.title,
                symbolName: "sparkles"
            )
            return item
        }

        return nil
    }

    private func touchBarButtonItem(
        identifier: NSTouchBarItem.Identifier,
        title: String,
        symbolName: String
    ) -> NSButtonTouchBarItem {
        let item = NSButtonTouchBarItem(
            identifier: identifier,
            title: title,
            target: self,
            action: #selector(handleTouchBarItemAction(_:))
        )
        item.bezelColor = .controlAccentColor
        item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
        item.customizationLabel = title
        item.target = self
        item.action = #selector(handleTouchBarItemAction(_:))
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

        modeControl.segmentStyle = .rounded
        modeControl.selectedSegment = WorkspaceMode.use.rawValue
        modeControl.target = self
        modeControl.action = #selector(handleModeChange(_:))

        rotateLayoutButton.bezelStyle = .rounded
        rotateLayoutButton.target = self
        rotateLayoutButton.action = #selector(handleRotateLayout(_:))

        let controlRow = NSStackView(views: [profileControl, modeControl, rotateLayoutButton])
        controlRow.orientation = .horizontal
        controlRow.alignment = .centerY
        controlRow.spacing = 12

        let modulesTitle = NSTextField(labelWithString: "Essential apps")
        modulesTitle.font = .systemFont(ofSize: 14, weight: .semibold)

        moduleStack.orientation = .vertical
        moduleStack.alignment = .leading
        moduleStack.spacing = 10
        moduleStack.translatesAutoresizingMaskIntoConstraints = false

        configureCreatePanel()

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

        let rootStack = NSStackView(views: [headingStack, controlRow, modulesTitle, moduleStack, createPanel, statusContainer])
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

    private func configureCreatePanel() {
        createPanel.material = .menu
        createPanel.blendingMode = .withinWindow
        createPanel.state = .active
        createPanel.wantsLayer = true
        createPanel.layer?.cornerRadius = 12
        createPanel.translatesAutoresizingMaskIntoConstraints = false
        createPanel.isHidden = true

        let createTitle = NSTextField(labelWithString: "Create mode")
        createTitle.font = .systemFont(ofSize: 14, weight: .semibold)

        let createSubtitle = NSTextField(labelWithString: "Build custom Touch Bar buttons that paste text anywhere.")
        createSubtitle.font = .systemFont(ofSize: 12, weight: .regular)
        createSubtitle.textColor = .secondaryLabelColor

        customTitleField.placeholderString = "Button title (e.g. Daily Standup)"
        customPayloadField.placeholderString = "Button payload (text copied to clipboard)"

        addCustomActionButton.bezelStyle = .rounded
        addCustomActionButton.target = self
        addCustomActionButton.action = #selector(handleAddCustomAction(_:))

        customActionsStack.orientation = .vertical
        customActionsStack.alignment = .leading
        customActionsStack.spacing = 8

        let createHeader = NSStackView(views: [createTitle, createSubtitle])
        createHeader.orientation = .vertical
        createHeader.alignment = .leading
        createHeader.spacing = 4

        let formStack = NSStackView(views: [customTitleField, customPayloadField, addCustomActionButton])
        formStack.orientation = .horizontal
        formStack.alignment = .centerY
        formStack.spacing = 8

        let panelStack = NSStackView(views: [createHeader, formStack, customActionsStack])
        panelStack.orientation = .vertical
        panelStack.alignment = .leading
        panelStack.spacing = 10
        panelStack.translatesAutoresizingMaskIntoConstraints = false
        createPanel.addSubview(panelStack)

        NSLayoutConstraint.activate([
            createPanel.widthAnchor.constraint(greaterThanOrEqualToConstant: 640),
            customTitleField.widthAnchor.constraint(equalToConstant: 180),
            customPayloadField.widthAnchor.constraint(equalToConstant: 300),
            panelStack.topAnchor.constraint(equalTo: createPanel.topAnchor, constant: 14),
            panelStack.leadingAnchor.constraint(equalTo: createPanel.leadingAnchor, constant: 14),
            panelStack.trailingAnchor.constraint(equalTo: createPanel.trailingAnchor, constant: -14),
            panelStack.bottomAnchor.constraint(equalTo: createPanel.bottomAnchor, constant: -14)
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

            try loadCustomActions()
            renderModuleCards()
            renderCustomActionsList()
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

    private func renderCustomActionsList() {
        customActionsStack.arrangedSubviews.forEach { view in
            customActionsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        guard !customActions.isEmpty else {
            let emptyLabel = NSTextField(labelWithString: "No custom buttons yet.")
            emptyLabel.textColor = .secondaryLabelColor
            customActionsStack.addArrangedSubview(emptyLabel)
            return
        }

        for action in customActions {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 8

            let label = NSTextField(labelWithString: "\(action.title) → \(action.payload)")
            label.font = .systemFont(ofSize: 12, weight: .regular)
            label.lineBreakMode = .byTruncatingTail
            label.maximumNumberOfLines = 1
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

            let deleteButton = NSButton(title: "Delete", target: self, action: #selector(handleDeleteCustomAction(_:)))
            deleteButton.bezelStyle = .rounded
            deleteButton.identifier = NSUserInterfaceItemIdentifier(action.id)

            row.addArrangedSubview(label)
            row.addArrangedSubview(deleteButton)
            row.widthAnchor.constraint(equalToConstant: 560).isActive = true
            customActionsStack.addArrangedSubview(row)
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
        let newTouchBar = makeTouchBar()
        touchBar = newTouchBar
        view.window?.touchBar = newTouchBar
    }

    private func customIdentifier(for action: CustomTouchBarAction) -> NSTouchBarItem.Identifier {
        NSTouchBarItem.Identifier("\(customIdentifierPrefix)\(action.id)")
    }

    private func customAction(for identifier: NSTouchBarItem.Identifier) -> CustomTouchBarAction? {
        guard identifier.rawValue.hasPrefix(customIdentifierPrefix) else {
            return nil
        }
        let actionID = String(identifier.rawValue.dropFirst(customIdentifierPrefix.count))
        return customActions.first(where: { $0.id == actionID })
    }

    private func currentWorkspaceMode() -> WorkspaceMode {
        WorkspaceMode(rawValue: modeControl.selectedSegment) ?? .use
    }

    private func applyModeVisibility() {
        createPanel.isHidden = currentWorkspaceMode() == .use
    }

    private func loadCustomActions() throws {
        guard let profileID = currentProfile?.id else {
            customActions = []
            return
        }
        customActions = try customActionStore.actions(for: profileID)
    }

    private func runCustomAction(_ action: CustomTouchBarAction) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(action.payload, forType: .string)
        updateStatus("Custom button \(action.title) copied payload to clipboard.")
    }

    @objc
    private func handleTouchBarItemAction(_ sender: NSButtonTouchBarItem) {
        let rawIdentifier = sender.identifier.rawValue
        if rawIdentifier.isEmpty {
            updateStatus("Unknown action.")
            return
        }

        if let module = EssentialModule.allCases.first(where: { $0.itemIdentifier.rawValue == rawIdentifier }) {
            perform(module)
            return
        }

        if rawIdentifier.hasPrefix(customIdentifierPrefix) {
            let actionID = String(rawIdentifier.dropFirst(customIdentifierPrefix.count))
            guard let action = customActions.first(where: { $0.id == actionID }) else {
                updateStatus("Custom action not found.")
                return
            }
            runCustomAction(action)
            return
        }

        updateStatus("Unknown action.")
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
            try loadCustomActions()
            renderModuleCards()
            renderCustomActionsList()
            reloadTouchBar()
            updateStatus("Profile \(selectedProfile.name) active.")
        } catch {
            updateStatus("Profile switch error: \(error.localizedDescription)")
        }
    }

    @objc
    private func handleModeChange(_ sender: NSSegmentedControl) {
        applyModeVisibility()
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

    @objc
    private func handleAddCustomAction(_ sender: NSButton) {
        do {
            guard let profileID = currentProfile?.id else {
                throw ReviveBARError.invalidProfileSelection
            }
            customActions = try customActionStore.addAction(
                profileID: profileID,
                title: customTitleField.stringValue,
                payload: customPayloadField.stringValue
            )
            customTitleField.stringValue = ""
            customPayloadField.stringValue = ""
            renderCustomActionsList()
            reloadTouchBar()
            updateStatus("Custom button created.")
        } catch {
            updateStatus("Create mode error: \(error.localizedDescription)")
        }
    }

    @objc
    private func handleDeleteCustomAction(_ sender: NSButton) {
        do {
            guard let profileID = currentProfile?.id else {
                throw ReviveBARError.invalidProfileSelection
            }
            guard let actionID = sender.identifier?.rawValue else {
                return
            }
            customActions = try customActionStore.deleteAction(profileID: profileID, actionID: actionID)
            renderCustomActionsList()
            reloadTouchBar()
            updateStatus("Custom button removed.")
        } catch {
            updateStatus("Delete error: \(error.localizedDescription)")
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
