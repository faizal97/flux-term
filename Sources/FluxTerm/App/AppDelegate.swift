import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windows: [MainWindow] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        setAppIcon()
        setupMenuBar()
        do {
            let window = try createWindow()
            window.showWindow(nil)
        } catch {
            presentStartupError(error)
            NSApp.terminate(nil)
            return
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNewTabRequest(_:)),
            name: .newTabRequested,
            object: nil
        )
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setAppIcon() {
        guard let url = AppResources.url(forResource: "AppIcon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return }
        NSApp.applicationIconImage = image
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @objc func newWindow(_ sender: Any?) {
        do {
            let window = try createWindow()
            window.showWindow(sender)
        } catch {
            presentStartupError(error)
        }
    }

    @objc private func windowWillClose(_ notification: Notification) {
        guard let closedWindow = notification.object as? NSWindow else { return }
        windows.removeAll { $0.window === closedWindow }
    }

    @objc private func handleNewTabRequest(_ notification: Notification) {
        guard let container = notification.object as? TabContainerViewController else { return }
        guard let mainWindow = windows.first(where: { $0.tabContainer === container }) else { return }
        mainWindow.newTab(nil)
    }

    private func presentStartupError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "FluxTerm couldn't start"
        alert.informativeText = """
        Failed to initialize the Metal renderer.

        \(error.localizedDescription)
        """
        alert.addButton(withTitle: "Quit")
        alert.runModal()
    }

    private func setupMenuBar() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "FluxTerm")
        appMenu.addItem(withTitle: "About FluxTerm", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit FluxTerm", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let shellMenuItem = NSMenuItem()
        let shellMenu = NSMenu(title: "Shell")
        shellMenu.addItem(NSMenuItem(title: "New Tab", action: #selector(MainWindow.newTab(_:)), keyEquivalent: "t"))
        shellMenu.addItem(NSMenuItem(title: "New Window", action: #selector(newWindow(_:)), keyEquivalent: "n"))
        shellMenu.addItem(.separator())
        shellMenu.addItem(NSMenuItem(title: "Close Tab", action: #selector(MainWindow.closeTab(_:)), keyEquivalent: "w"))
        shellMenu.addItem(.separator())

        let nextTabItem = NSMenuItem(title: "Show Next Tab", action: #selector(MainWindow.selectNextTab(_:)), keyEquivalent: "]")
        nextTabItem.keyEquivalentModifierMask = [.command, .shift]
        shellMenu.addItem(nextTabItem)

        let previousTabItem = NSMenuItem(title: "Show Previous Tab", action: #selector(MainWindow.selectPreviousTab(_:)), keyEquivalent: "[")
        previousTabItem.keyEquivalentModifierMask = [.command, .shift]
        shellMenu.addItem(previousTabItem)

        shellMenuItem.submenu = shellMenu
        mainMenu.addItem(shellMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(TerminalViewController.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(TerminalViewController.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSResponder.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(NSMenuItem(title: "Increase Font Size", action: #selector(TerminalViewController.increaseFontSize(_:)), keyEquivalent: "+"))
        viewMenu.addItem(NSMenuItem(title: "Decrease Font Size", action: #selector(TerminalViewController.decreaseFontSize(_:)), keyEquivalent: "-"))
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        NSApp.mainMenu = mainMenu
    }

    private func createWindow() throws -> MainWindow {
        let window = try MainWindow.make()
        windows.append(window)
        return window
    }
}
