import AppKit

final class MainWindow: NSWindowController {
    var terminalVC: TerminalViewController!

    convenience init() {
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
        window.backgroundColor = .clear
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

        let visualEffectView = NSVisualEffectView(frame: window.contentLayoutRect)
        visualEffectView.autoresizingMask = [.width, .height]
        visualEffectView.material = .sidebar
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        window.contentView = visualEffectView

        self.init(window: window)

        terminalVC = TerminalViewController()
        terminalVC.view.frame = visualEffectView.bounds
        terminalVC.view.autoresizingMask = [.width, .height]
        visualEffectView.addSubview(terminalVC.view)
        terminalVC.metalView.controller = terminalVC
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeFirstResponder(terminalVC.metalView)
    }
}
