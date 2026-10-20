import AppKit

final class ModuleCardView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let actionButton = NSButton(title: "", target: nil, action: nil)
    private var tapHandler: (() -> Void)?

    init(module: EssentialModule, actionTitle: String, onTap: @escaping () -> Void) {
        self.tapHandler = onTap
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setup(module: module, actionTitle: actionTitle)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setActionTitle(_ title: String) {
        actionButton.title = title
    }

    private func setup(module: EssentialModule, actionTitle: String) {
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        layer?.borderWidth = 1

        let iconContainer = NSView()
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = 10
        iconContainer.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.08).cgColor
        iconContainer.translatesAutoresizingMaskIntoConstraints = false

        let iconImageView = NSImageView()
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        iconImageView.image = NSImage(systemSymbolName: module.symbolName, accessibilityDescription: module.title)?
            .withSymbolConfiguration(symbolConfig)
        iconImageView.contentTintColor = .labelColor
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconImageView)

        titleLabel.stringValue = module.title
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .labelColor

        subtitleLabel.stringValue = module.subtitle
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor

        let textStack = NSStackView(views: [titleLabel, subtitleLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4

        actionButton.title = actionTitle
        actionButton.bezelStyle = .rounded
        actionButton.font = .systemFont(ofSize: 12, weight: .medium)
        actionButton.target = self
        actionButton.action = #selector(handleTap)

        let contentStack = NSStackView(views: [iconContainer, textStack, actionButton])
        contentStack.orientation = .horizontal
        contentStack.alignment = .centerY
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(contentStack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 84),
            iconContainer.widthAnchor.constraint(equalToConstant: 40),
            iconContainer.heightAnchor.constraint(equalToConstant: 40),
            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        ])
    }

    @objc
    private func handleTap() {
        tapHandler?()
    }
}
