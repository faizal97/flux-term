import AppKit

final class TabContainerViewController: NSViewController {
    private(set) var tabs: [TabItem] = []
    private(set) var selectedIndex: Int = 0
    private(set) var contentAreaView: NSView!
    private(set) var tabBarView: TabBarView!

    var onLastTabClosed: (() -> Void)?

    private var contentTopConstraint: NSLayoutConstraint!
    private var tabBarHeightConstraint: NSLayoutConstraint!

    var activeTab: TabItem? {
        guard selectedIndex >= 0 && selectedIndex < tabs.count else { return nil }
        return tabs[selectedIndex]
    }

    var activeTerminalVC: TerminalViewController? {
        activeTab?.terminalVC
    }

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 960, height: 640))
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor(
            red: 0.118,
            green: 0.118,
            blue: 0.180,
            alpha: 1.0
        ).cgColor
        view = root

        tabBarView = TabBarView(frame: .zero)
        tabBarView.translatesAutoresizingMaskIntoConstraints = false
        tabBarView.delegate = self
        root.addSubview(tabBarView)

        contentAreaView = NSView(frame: .zero)
        contentAreaView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(contentAreaView)

        tabBarHeightConstraint = tabBarView.heightAnchor.constraint(equalToConstant: 0)
        contentTopConstraint = contentAreaView.topAnchor.constraint(equalTo: root.topAnchor)

        NSLayoutConstraint.activate([
            tabBarView.topAnchor.constraint(equalTo: root.topAnchor),
            tabBarView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            tabBarView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            tabBarHeightConstraint,
            contentTopConstraint,
            contentAreaView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            contentAreaView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            contentAreaView.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])

        updateLayout()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateLayout()
    }

    func addTab(_ tab: TabItem) {
        configure(tab: tab)
        tabs.append(tab)

        if tabs.count == 1 {
            selectedIndex = -1
            selectTab(at: 0)
        } else {
            updateTabBar()
        }
    }

    func removeTab(at index: Int) {
        guard index >= 0 && index < tabs.count else { return }

        let removedVC = tabs[index].terminalVC
        removedVC.onSessionTerminated = nil
        removedVC.onTitleChanged = nil

        let wasSelected = index == selectedIndex
        if wasSelected {
            removedVC.view.removeFromSuperview()
            removedVC.removeFromParent()
        }

        tabs.remove(at: index)

        guard !tabs.isEmpty else {
            selectedIndex = 0
            updateTabBar()
            onLastTabClosed?()
            return
        }

        if wasSelected {
            let newIndex = min(index, tabs.count - 1)
            selectedIndex = -1
            selectTab(at: newIndex)
            return
        }

        if selectedIndex > index {
            selectedIndex -= 1
        }

        updateTabBar()
    }

    func selectTab(at index: Int) {
        guard index >= 0 && index < tabs.count else { return }

        let currentSelectionIsVisible =
            selectedIndex >= 0 &&
            selectedIndex < tabs.count &&
            tabs[selectedIndex].terminalVC.view.superview === contentAreaView
        if index == selectedIndex && currentSelectionIsVisible {
            return
        }

        if currentSelectionIsVisible {
            tabs[selectedIndex].terminalVC.view.removeFromSuperview()
            tabs[selectedIndex].terminalVC.removeFromParent()
        }

        selectedIndex = index
        let tab = tabs[index]
        addChild(tab.terminalVC)
        let terminalView = tab.terminalVC.view
        terminalView.frame = contentAreaView.bounds
        terminalView.autoresizingMask = [.width, .height]
        contentAreaView.addSubview(terminalView)
        updateTabBar()
        view.window?.title = tab.title
        view.window?.makeFirstResponder(tab.terminalVC.metalView)
    }

    func selectNextTab() {
        guard tabs.count > 1 else { return }
        selectTab(at: (selectedIndex + 1) % tabs.count)
    }

    func selectPreviousTab() {
        guard tabs.count > 1 else { return }
        selectTab(at: (selectedIndex - 1 + tabs.count) % tabs.count)
    }

    func updateTabTitle(_ title: String, at index: Int) {
        guard index >= 0 && index < tabs.count else { return }
        tabs[index].title = title
        updateTabBar()
        if index == selectedIndex {
            view.window?.title = title
        }
    }

    private func configure(tab: TabItem) {
        tab.terminalVC.onSessionTerminated = { [weak self, weak tab] in
            guard let self, let tab else { return }
            guard let index = self.tabs.firstIndex(where: { $0 === tab }) else { return }
            self.removeTab(at: index)
        }

        tab.terminalVC.onTitleChanged = { [weak self, weak tab] title in
            guard let self, let tab else { return }
            guard let index = self.tabs.firstIndex(where: { $0 === tab }) else { return }
            self.updateTabTitle(title, at: index)
        }
    }

    private func updateTabBar() {
        tabBarView.tabs = tabs.map { TabBarView.Tab(title: $0.title) }
        tabBarView.selectedIndex = max(0, selectedIndex)
        updateLayout()
    }

    private func updateLayout() {
        guard isViewLoaded else { return }

        let showTabBar = tabs.count > 1
        tabBarView.isHidden = !showTabBar
        tabBarHeightConstraint.constant = showTabBar ? TabBarView.height : 0
        contentTopConstraint.constant = showTabBar ? TabBarView.height : 0
        activeTerminalVC?.view.frame = contentAreaView.bounds
    }
}

extension TabContainerViewController: TabBarViewDelegate {
    func tabBarDidSelectTab(at index: Int) {
        selectTab(at: index)
    }

    func tabBarDidCloseTab(at index: Int) {
        removeTab(at: index)
    }

    func tabBarDidRequestNewTab() {
        NotificationCenter.default.post(name: .newTabRequested, object: self)
    }
}

extension Notification.Name {
    static let newTabRequested = Notification.Name("FluxTermNewTabRequested")
}
