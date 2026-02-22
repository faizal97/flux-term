import XCTest
@testable import FluxTerm

final class TerminalViewControllerSelectionTests: XCTestCase {
    private func makeController(cols: Int = 120, rows: Int = 3) -> TerminalViewController {
        let controller = try! TerminalViewController()
        controller.session = TerminalSession(cols: cols, rows: rows)
        return controller
    }

    private func primeScrollback(_ controller: TerminalViewController) -> Int {
        let lines = (0..<8).map { "row-\($0)-abcdef" }
        controller.session.terminal.feed(text: lines.joined(separator: "\r\n"))
        let liveTop = controller.session.terminal.getTopVisibleRow()
        XCTAssertGreaterThan(liveTop, 1, "Expected non-zero scrollback after priming terminal output")

        let scrolledTop = max(0, liveTop - 2)
        controller.session.terminal.buffer.yDisp = scrolledTop
        return scrolledTop
    }

    func testBufferRowAccountsForScrollOffset() {
        let controller = makeController(rows: 4)
        controller.session.terminal.buffer.yDisp = 9

        XCTAssertEqual(controller.bufferRow(for: 0), 9)
        XCTAssertEqual(controller.bufferRow(for: 3), 12)
    }

    func testIsSelectedMatchesBufferRowsWhenScrolledBack() {
        let controller = makeController(rows: 3)
        let scrolledTop = primeScrollback(controller)
        let selectedRow = scrolledTop + 1

        controller.selectionStart = TerminalViewController.CellPosition(col: 2, row: selectedRow)
        controller.selectionEnd = TerminalViewController.CellPosition(col: 5, row: selectedRow)

        XCTAssertTrue(controller.isSelected(col: 3, row: selectedRow))
        XCTAssertFalse(controller.isSelected(col: 1, row: selectedRow))
    }

    func testGetSelectedTextReturnsScrollbackContentWhenRowsAreBufferRelative() {
        let controller = makeController(rows: 3)
        let scrolledTop = primeScrollback(controller)
        let selectedRow = scrolledTop + 1
        let startCol = 0
        let endCol = 6

        controller.selectionStart = TerminalViewController.CellPosition(col: startCol, row: selectedRow)
        controller.selectionEnd = TerminalViewController.CellPosition(col: endCol, row: selectedRow)

        guard let line = controller.session.terminal.getScrollInvariantLine(row: selectedRow) else {
            XCTFail("Expected selected scrollback line at row \(selectedRow)")
            return
        }

        var expected = ""
        for col in startCol...endCol {
            let char = controller.session.terminal.getCharacter(for: line[col])
            if char != "\0" {
                expected.append(char)
            }
        }

        XCTAssertEqual(controller.getSelectedText(), expected)
    }
}
