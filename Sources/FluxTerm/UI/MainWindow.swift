import AppKit

final class MainWindow: NSWindowController {
    let tabContainer: TabContainerViewController

    static func make() throws -> MainWindow {
        let tabContainer = TabContainerViewController()
        let windowController = MainWindow(tabContainer: tabContainer)
        let initialVC = try TerminalViewController()
        tabContainer.addTab(TabItem(terminalVC: initialVC))
        return windowController
    }

    private init(tabContainer: TabContainerViewController) {
        self.tabContainer = tabContainer

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

        tabContainer.view.frame = contentView.bounds
        tabContainer.view.autoresizingMask = [.width, .height]
        contentView.addSubview(tabContainer.view)

        tabContainer.onLastTabClosed = { [weak self] in
            self?.window?.close()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.title = tabContainer.activeTab?.title ?? "FluxTerm"
        if let metalView = tabContainer.activeTerminalVC?.metalView {
            window?.makeFirstResponder(metalView)
        }
    }

    func addNewTab() throws {
        let terminalVC = try TerminalViewController()
        let tab = TabItem(terminalVC: terminalVC)
        tabContainer.addTab(tab)
        tabContainer.selectTab(at: tabContainer.tabs.count - 1)
    }

    @objc func newTab(_ sender: Any?) {
        do {
            try addNewTab()
        } catch {
            presentTabError(error)
        }
    }

    private func presentTabError(_ error: Error) {
        guard let window else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Couldn't open new tab"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window)
    }

    @objc func closeTab(_ sender: Any?) {
        guard !tabContainer.tabs.isEmpty else { return }
        tabContainer.removeTab(at: tabContainer.selectedIndex)
    }

    @objc func selectNextTab(_ sender: Any?) {
        tabContainer.selectNextTab()
    }

    @objc func selectPreviousTab(_ sender: Any?) {
        tabContainer.selectPreviousTab()
    }
}
