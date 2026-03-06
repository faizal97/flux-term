import XCTest
@testable import FluxTerm

final class TabContainerViewControllerTests: XCTestCase {
    private func makeTab(title: String = "FluxTerm") -> TabItem {
        let vc = try! TerminalViewController()
        vc.startsSessionAutomatically = false
        return TabItem(title: title, terminalVC: vc)
    }

    func testAddFirstTabSelectsIt() {
        let container = TabContainerViewController()
        container.loadViewIfNeeded()
        let tab = makeTab()

        container.addTab(tab)

        XCTAssertEqual(container.tabs.count, 1)
        XCTAssertEqual(container.selectedIndex, 0)
        XCTAssertTrue(container.activeTab === tab)
        XCTAssertTrue(container.tabBarView.isHidden)
    }

    func testAddSecondTabDoesNotChangeSelection() {
        let container = TabContainerViewController()
        container.loadViewIfNeeded()
        let tab1 = makeTab(title: "tab1")
        let tab2 = makeTab(title: "tab2")

        container.addTab(tab1)
        container.addTab(tab2)

        XCTAssertEqual(container.tabs.count, 2)
        XCTAssertEqual(container.selectedIndex, 0)
        XCTAssertTrue(container.activeTab === tab1)
        XCTAssertFalse(container.tabBarView.isHidden)
    }

    func testSelectTab() {
        let container = TabContainerViewController()
        container.loadViewIfNeeded()
        let tab1 = makeTab(title: "tab1")
        let tab2 = makeTab(title: "tab2")

        container.addTab(tab1)
        container.addTab(tab2)
        container.selectTab(at: 1)

        XCTAssertEqual(container.selectedIndex, 1)
        XCTAssertTrue(container.activeTab === tab2)
    }

    func testSelectTabOutOfRangeIsIgnored() {
        let container = TabContainerViewController()
        container.loadViewIfNeeded()
        container.addTab(makeTab())

        container.selectTab(at: 5)

        XCTAssertEqual(container.selectedIndex, 0)
    }

    func testSelectNegativeIndexIsIgnored() {
        let container = TabContainerViewController()
        container.loadViewIfNeeded()
        container.addTab(makeTab())

        container.selectTab(at: -1)

        XCTAssertEqual(container.selectedIndex, 0)
    }

    func testSelectNextTabWraps() {
        let container = TabContainerViewController()
        container.loadViewIfNeeded()
        container.addTab(makeTab(title: "tab1"))
        container.addTab(makeTab(title: "tab2"))
        container.addTab(makeTab(title: "tab3"))
        container.selectTab(at: 2)

        container.selectNextTab()

        XCTAssertEqual(container.selectedIndex, 0)
    }

    func testSelectPreviousTabWraps() {
        let container = TabContainerViewController()
        container.loadViewIfNeeded()
        container.addTab(makeTab(title: "tab1"))
        container.addTab(makeTab(title: "tab2"))
        container.addTab(makeTab(title: "tab3"))

        container.selectPreviousTab()

        XCTAssertEqual(container.selectedIndex, 2)
    }

    func testSelectNextTabSingleTabNoOp() {
        let container = TabContainerViewController()
        container.loadViewIfNeeded()
        container.addTab(makeTab())

        container.selectNextTab()

        XCTAssertEqual(container.selectedIndex, 0)
    }

    func testRemoveSelectedTabSelectsNeighbor() {
        let container = TabContainerViewController()
        container.loadViewIfNeeded()
        let tab1 = makeTab(title: "tab1")
        let tab2 = makeTab(title: "tab2")
        let tab3 = makeTab(title: "tab3")
        container.addTab(tab1)
        container.addTab(tab2)
        container.addTab(tab3)
        container.selectTab(at: 1)

        container.removeTab(at: 1)

        XCTAssertEqual(container.tabs.count, 2)
        XCTAssertEqual(container.selectedIndex, 1)
        XCTAssertTrue(container.activeTab === tab3)
    }

    func testRemoveLastSelectedTabSelectsPrevious() {
        let container = TabContainerViewController()
        container.loadViewIfNeeded()
        let tab1 = makeTab(title: "tab1")
        let tab2 = makeTab(title: "tab2")
        container.addTab(tab1)
        container.addTab(tab2)
        container.selectTab(at: 1)

        container.removeTab(at: 1)

        XCTAssertEqual(container.selectedIndex, 0)
        XCTAssertTrue(container.activeTab === tab1)
    }

    func testRemoveNonSelectedTabBeforeSelectedAdjustsIndex() {
        let container = TabContainerViewController()
        container.loadViewIfNeeded()
        let tab1 = makeTab(title: "tab1")
        let tab2 = makeTab(title: "tab2")
        let tab3 = makeTab(title: "tab3")
        container.addTab(tab1)
        container.addTab(tab2)
        container.addTab(tab3)
        container.selectTab(at: 2)

        container.removeTab(at: 0)

        XCTAssertEqual(container.selectedIndex, 1)
        XCTAssertTrue(container.activeTab === tab3)
    }

    func testRemoveNonSelectedTabAfterSelectedKeepsIndex() {
        let container = TabContainerViewController()
        container.loadViewIfNeeded()
        let tab1 = makeTab(title: "tab1")
        let tab2 = makeTab(title: "tab2")
        let tab3 = makeTab(title: "tab3")
        container.addTab(tab1)
        container.addTab(tab2)
        container.addTab(tab3)
        container.selectTab(at: 0)

        container.removeTab(at: 2)

        XCTAssertEqual(container.selectedIndex, 0)
        XCTAssertTrue(container.activeTab === tab1)
    }

    func testRemoveOutOfRangeIsIgnored() {
        let container = TabContainerViewController()
        container.loadViewIfNeeded()
        container.addTab(makeTab())

        container.removeTab(at: 5)

        XCTAssertEqual(container.tabs.count, 1)
    }

    func testRemoveLastTabReportsEmpty() {
        let container = TabContainerViewController()
        container.loadViewIfNeeded()
        container.addTab(makeTab())

        var didCloseLastTab = false
        container.onLastTabClosed = { didCloseLastTab = true }

        container.removeTab(at: 0)

        XCTAssertTrue(container.tabs.isEmpty)
        XCTAssertTrue(didCloseLastTab)
    }

    func testActiveTabViewIsInContentArea() {
        let container = TabContainerViewController()
        container.loadViewIfNeeded()
        let tab = makeTab()

        container.addTab(tab)

        XCTAssertTrue(tab.terminalVC.view.superview === container.contentAreaView)
    }

    func testSwitchingTabSwapsView() {
        let container = TabContainerViewController()
        container.loadViewIfNeeded()
        let tab1 = makeTab(title: "tab1")
        let tab2 = makeTab(title: "tab2")
        container.addTab(tab1)
        container.addTab(tab2)

        container.selectTab(at: 1)

        XCTAssertNil(tab1.terminalVC.view.superview)
        XCTAssertTrue(tab2.terminalVC.view.superview === container.contentAreaView)
    }

    func testUpdateTabTitleMutatesTabModel() {
        let container = TabContainerViewController()
        container.loadViewIfNeeded()
        let tab = makeTab()
        container.addTab(tab)

        container.updateTabTitle("vim", at: 0)

        XCTAssertEqual(container.tabs[0].title, "vim")
        XCTAssertEqual(container.tabBarView.tabs.first?.title, "vim")
    }
}
