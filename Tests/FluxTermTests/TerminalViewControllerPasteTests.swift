import XCTest
import SwiftTerm
@testable import FluxTerm

final class TerminalViewControllerPasteTests: XCTestCase {
    private func makeController(cols: Int = 80, rows: Int = 24) -> TerminalViewController {
        let controller = try! TerminalViewController()
        controller.session = TerminalSession(cols: cols, rows: rows)
        return controller
    }

    func testEncodedPastePayloadWhenBracketedPasteDisabledSendsRawUTF8() {
        let controller = makeController()
        let text = "echo hello\n"

        let payload = controller.encodedPastePayload(for: text)

        XCTAssertFalse(controller.session.terminal.bracketedPasteMode)
        XCTAssertEqual(payload, Array(text.utf8))
    }

    func testEncodedPastePayloadWhenBracketedPasteEnabledWrapsInput() {
        let controller = makeController()
        controller.session.terminal.feed(text: "\u{1b}[?2004h")
        let text = "echo safe-paste"

        let payload = controller.encodedPastePayload(for: text)
        let expected =
            EscapeSequences.bracketedPasteStart +
            Array(text.utf8) +
            EscapeSequences.bracketedPasteEnd

        XCTAssertTrue(controller.session.terminal.bracketedPasteMode)
        XCTAssertEqual(payload, expected)
    }

    func testEncodedPastePayloadStopsWrappingAfterModeDisabled() {
        let controller = makeController()
        controller.session.terminal.feed(text: "\u{1b}[?2004h")
        controller.session.terminal.feed(text: "\u{1b}[?2004l")
        let text = "echo raw-again"

        let payload = controller.encodedPastePayload(for: text)

        XCTAssertFalse(controller.session.terminal.bracketedPasteMode)
        XCTAssertEqual(payload, Array(text.utf8))
    }
}
