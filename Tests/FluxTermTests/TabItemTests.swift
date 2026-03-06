import XCTest
@testable import FluxTerm

final class TabItemTests: XCTestCase {
    func testInitializationDefaultTitle() {
        let vc = try! TerminalViewController()
        let tab = TabItem(terminalVC: vc)

        XCTAssertEqual(tab.title, "FluxTerm")
        XCTAssertNotNil(tab.id)
        XCTAssertTrue(tab.terminalVC === vc)
    }

    func testInitializationCustomTitle() {
        let vc = try! TerminalViewController()
        let tab = TabItem(title: "zsh", terminalVC: vc)

        XCTAssertEqual(tab.title, "zsh")
    }

    func testTitleMutable() {
        let vc = try! TerminalViewController()
        let tab = TabItem(terminalVC: vc)

        tab.title = "vim"
        XCTAssertEqual(tab.title, "vim")
    }

    func testUniqueIdentifiers() {
        let vc = try! TerminalViewController()
        let tab1 = TabItem(terminalVC: vc)
        let tab2 = TabItem(terminalVC: vc)

        XCTAssertNotEqual(tab1.id, tab2.id)
    }
}
