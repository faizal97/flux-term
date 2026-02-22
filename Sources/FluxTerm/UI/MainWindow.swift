import AppKit

final class MainWindow: NSWindowController {
    let terminalVC: TerminalViewController

    init() {
        terminalVC = TerminalViewController()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 640),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "FluxTerm"
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(
            red: 0.118,
            green: 0.118,
            blue: 0.180,
            alpha: 1.0
        )
        window.isOpaque = true
        window.minSize = NSSize(width: 500, height: 320)
        window.isMovableByWindowBackground = true

        // Inset traffic light buttons.
        if let closeButton = window.standardWindowButton(.closeButton),
           let miniaturizeButton = window.standardWindowButton(.miniaturizeButton),
           let zoomButton = window.standardWindowButton(.zoomButton) {
            let y = closeButton.frame.origin.y
            closeButton.setFrameOrigin(NSPoint(x: 14, y: y))
            miniaturizeButton.setFrameOrigin(NSPoint(x: 34, y: y))
            zoomButton.setFrameOrigin(NSPoint(x: 54, y: y))
        }

        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor(
            red: 0.118,
            green: 0.118,
            blue: 0.180,
            alpha: 1.0
        ).cgColor
        contentView.autoresizingMask = [.width, .height]
        window.contentView = contentView

        super.init(window: window)

        terminalVC.view.frame = contentView.bounds
        terminalVC.view.autoresizingMask = [.width, .height]
        contentView.addSubview(terminalVC.view)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeFirstResponder(terminalVC.metalView)
    }
}
