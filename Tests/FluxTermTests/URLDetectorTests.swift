import XCTest
import SwiftTerm
@testable import FluxTerm

final class URLDetectorTests: XCTestCase {
    private func makeTerminal(cols: Int = 120, rows: Int = 6) -> Terminal {
        let options = TerminalOptions(cols: cols, rows: rows, termName: "xterm-256color", scrollback: 1000)
        return Terminal(delegate: TestTerminalDelegate(), options: options)
    }

    func testDetectsSingleURLOnFirstRow() {
        let terminal = makeTerminal()
        terminal.feed(text: "Visit https://example.com today")

        let detected = URLDetector.detectURLs(in: terminal)
        // With no scrollback yet, top visible row is 0 so the URL row is 0.
        XCTAssertEqual(detected.count, 1)
        XCTAssertEqual(detected[0].url.absoluteString, "https://example.com")
        XCTAssertEqual(detected[0].row, 0)
        XCTAssertEqual(detected[0].startCol, 6)
    }

    func testDetectsMultipleURLsOnSameRow() {
        let terminal = makeTerminal()
        terminal.feed(text: "first https://a.example and https://b.example/path")

        let detected = URLDetector.detectURLs(in: terminal)
        guard detected.count == 2 else {
            XCTFail("Expected 2 URLs, got \(detected.count)")
            return
        }
        let first = detected[0]
        let second = detected[1]

        XCTAssertEqual(first.row, 0)
        XCTAssertEqual(first.url.absoluteString, "https://a.example")
        XCTAssertEqual(second.row, 0)
        XCTAssertEqual(second.url.absoluteString, "https://b.example/path")
    }

    func testURLAtReturnsMatchWithinBounds() {
        let urls = [
            DetectedURL(url: URL(string: "https://example.com")!, startCol: 3, endCol: 8, row: 2)
        ]

        XCTAssertNotNil(URLDetector.urlAt(col: 3, row: 2, in: urls))
        XCTAssertNotNil(URLDetector.urlAt(col: 8, row: 2, in: urls))
        XCTAssertNil(URLDetector.urlAt(col: 2, row: 2, in: urls))
        XCTAssertNil(URLDetector.urlAt(col: 9, row: 2, in: urls))
        XCTAssertNil(URLDetector.urlAt(col: 4, row: 1, in: urls))
    }

    func testDetectsNoURLsInPlainText() {
        let terminal = makeTerminal()
        terminal.feed(text: "no links here")

        XCTAssertTrue(URLDetector.detectURLs(in: terminal).isEmpty)
    }

    func testDetectsURLAfterWideCharacters() {
        let terminal = makeTerminal()
        // CJK characters occupy 2 terminal columns each:
        // '你' at cols 0-1, '好' at cols 2-3, ' ' at col 4, URL starts at col 5
        terminal.feed(text: "你好 https://example.com")

        let detected = URLDetector.detectURLs(in: terminal)
        XCTAssertEqual(detected.count, 1)
        XCTAssertEqual(detected[0].url.absoluteString, "https://example.com")
        XCTAssertEqual(detected[0].startCol, 5, "URL column should account for wide CJK characters before it")
        // "https://example.com" is 19 chars (all ASCII, width 1 each), so endCol = 5 + 19 - 1 = 23
        XCTAssertEqual(detected[0].endCol, 23)
    }

    func testURLAtWorksWithWideCharacterOffset() {
        let terminal = makeTerminal()
        terminal.feed(text: "你好 https://example.com")

        let detected = URLDetector.detectURLs(in: terminal)
        XCTAssertEqual(detected.count, 1)

        // Click on the URL area (col 5-23) should match
        XCTAssertNotNil(URLDetector.urlAt(col: 5, row: 0, in: detected))
        XCTAssertNotNil(URLDetector.urlAt(col: 15, row: 0, in: detected))
        XCTAssertNotNil(URLDetector.urlAt(col: 23, row: 0, in: detected))
        // Click before the URL (in the CJK text area) should not match
        XCTAssertNil(URLDetector.urlAt(col: 4, row: 0, in: detected))
        // Click after the URL should not match
        XCTAssertNil(URLDetector.urlAt(col: 24, row: 0, in: detected))
    }

    func testDetectRowsAreScrollInvariantWhenScrolledBack() {
        let terminal = makeTerminal(cols: 120, rows: 3)
        let lines = (0..<7).map { "line-\($0) https://example\($0).com" }
        terminal.feed(text: lines.joined(separator: "\r\n"))

        let liveTop = terminal.getTopVisibleRow()
        XCTAssertGreaterThan(liveTop, 0, "Expected scrollback after feeding more lines than viewport")

        let scrolledTop = max(0, liveTop - 2)
        terminal.buffer.yDisp = scrolledTop

        let detected = URLDetector.detectURLs(in: terminal)
        XCTAssertFalse(detected.isEmpty, "Expected URLs on visible scrolled rows")
        XCTAssertEqual(detected.count, terminal.rows, "Expected one URL per visible row")
        XCTAssertTrue(
            detected.allSatisfy { $0.row >= scrolledTop && $0.row < scrolledTop + terminal.rows },
            "Detected URL rows should be scroll-invariant buffer rows within the visible window"
        )

        let expectedRows = Array(scrolledTop..<(scrolledTop + terminal.rows))
        XCTAssertEqual(detected.map(\.row), expectedRows, "Detected rows should exactly match the visible scrollback window")

        for row in expectedRows {
            guard let match = detected.first(where: { $0.row == row }) else {
                XCTFail("Missing detected URL for row \(row)")
                return
            }
            XCTAssertEqual(match.url.absoluteString, "https://example\(row).com")
        }
    }
}
