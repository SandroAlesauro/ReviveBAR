import AppKit

final class MainWindowController: NSWindowController {
    init() {
        let contentRect = NSRect(x: 0, y: 0, width: 760, height: 460)
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        window.center()
        window.title = "ReviveBAR"
        window.contentViewController = MainViewController()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
