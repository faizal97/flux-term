import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindow: MainWindow?

    private weak var copyItem: NSMenuItem?
    private weak var pasteItem: NSMenuItem?
    private weak var selectAllItem: NSMenuItem?
    private weak var increaseFontItem: NSMenuItem?
    private weak var decreaseFontItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setAppIcon()
        mainWindow = MainWindow()
        setupMenuBar()
        wireMenuTargets()
        mainWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setAppIcon() {
        guard let url = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return }
        NSApp.applicationIconImage = image
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
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

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        let copy = NSMenuItem(title: "Copy", action: #selector(TerminalViewController.copy(_:)), keyEquivalent: "c")
        let paste = NSMenuItem(title: "Paste", action: #selector(TerminalViewController.paste(_:)), keyEquivalent: "v")
        let selectAll = NSMenuItem(title: "Select All", action: #selector(NSResponder.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(copy)
        editMenu.addItem(paste)
        editMenu.addItem(selectAll)
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        let increaseFont = NSMenuItem(title: "Increase Font Size", action: #selector(TerminalViewController.increaseFontSize(_:)), keyEquivalent: "+")
        let decreaseFont = NSMenuItem(title: "Decrease Font Size", action: #selector(TerminalViewController.decreaseFontSize(_:)), keyEquivalent: "-")
        viewMenu.addItem(increaseFont)
        viewMenu.addItem(decreaseFont)
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        copyItem = copy
        pasteItem = paste
        selectAllItem = selectAll
        increaseFontItem = increaseFont
        decreaseFontItem = decreaseFont

        NSApp.mainMenu = mainMenu
    }

    private func wireMenuTargets() {
        guard let vc = mainWindow?.terminalVC else { return }
        copyItem?.target = vc
        pasteItem?.target = vc
        selectAllItem?.target = vc
        increaseFontItem?.target = vc
        decreaseFontItem?.target = vc
    }
}
