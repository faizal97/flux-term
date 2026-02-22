import XCTest
import AppKit
@testable import FluxTerm

// MARK: - Pipeline Integration Tests
//
// These test the full handleKeyDown pipeline: real NSEvent → encodeKey →
// inputInterceptor. They require NSEvent construction and may skip on
// headless CI. Encoding correctness is covered exhaustively by
// KeyEncoderTests (no NSEvent dependency); these verify controller
// behavior: selection clearing, interceptor routing, command suppression.

final class KeyInputPipelineTests: XCTestCase {

    private var controller: TerminalViewController!
    private var capturedBytes: [[UInt8]]!

    override func setUp() {
        super.setUp()
        // Intentionally keep TerminalViewController in its pre-load state in setUp:
        // we do not call loadView because these tests exercise handleKeyDown routing
        // only. inputInterceptor is installed to capture bytes instead of writing to
        // the underlying session.
        controller = try! TerminalViewController()
        capturedBytes = []
        controller.inputInterceptor = { [weak self] bytes in
            self?.capturedBytes.append(bytes)
        }
    }

    override func tearDown() {
        controller = nil
        capturedBytes = nil
        super.tearDown()
    }

    private func makeKeyEvent(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags = [],
        characters: String = "",
        charactersIgnoringModifiers: String = ""
    ) throws -> NSEvent {
        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: charactersIgnoringModifiers,
            isARepeat: false,
            keyCode: keyCode
        ) else {
            throw XCTSkip("NSEvent.keyEvent returned nil — window server unavailable")
        }
        return event
    }

    private func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
    }

    // MARK: - Pipeline: Option+Letter (layout-independent)

    func testPipeline_OptionB_IgnoresLayoutCharacters() throws {
        let event = try makeKeyEvent(
            keyCode: 11,
            modifiers: .option,
            characters: "ß",
            charactersIgnoringModifiers: "b"
        )
        controller.handleKeyDown(event)
        XCTAssertEqual(capturedBytes.count, 1)
        XCTAssertEqual(capturedBytes[0], [0x1B, 0x62], "Pipeline: Option+B → \\eb regardless of layout")
    }

    // MARK: - Pipeline: Modifier+Arrow

    func testPipeline_CtrlLeftArrow() throws {
        let event = try makeKeyEvent(
            keyCode: 123,
            modifiers: [.control, .numericPad, .function],
            characters: "\u{F702}",
            charactersIgnoringModifiers: "\u{F702}"
        )
        controller.handleKeyDown(event)
        XCTAssertEqual(capturedBytes.count, 1)
        XCTAssertEqual(hex(capturedBytes[0]), "1b 5b 31 3b 35 44", "Pipeline: Ctrl+Left → \\e[1;5D")
    }

    // MARK: - Pipeline: F-key

    func testPipeline_F1() throws {
        let event = try makeKeyEvent(
            keyCode: 122,
            modifiers: .function,
            characters: "\u{F704}",
            charactersIgnoringModifiers: "\u{F704}"
        )
        controller.handleKeyDown(event)
        XCTAssertEqual(capturedBytes.count, 1)
        XCTAssertEqual(hex(capturedBytes[0]), "1b 4f 50", "Pipeline: F1 → \\eOP")
    }

    // MARK: - Pipeline: Command key produces no output

    func testPipeline_CommandKey_NoOutput() throws {
        let event = try makeKeyEvent(
            keyCode: 0,
            modifiers: .command,
            characters: "a",
            charactersIgnoringModifiers: "a"
        )
        controller.handleKeyDown(event)
        XCTAssertEqual(capturedBytes.count, 0, "Cmd+key should send nothing to PTY")
    }

    // MARK: - Pipeline: Multiple keys in sequence

    func testPipeline_MultipleKeysSequential() throws {
        let ctrlC = try makeKeyEvent(keyCode: 8, modifiers: .control, characters: "\u{03}", charactersIgnoringModifiers: "c")
        let letterA = try makeKeyEvent(keyCode: 0, characters: "a", charactersIgnoringModifiers: "a")
        let f10 = try makeKeyEvent(keyCode: 109, modifiers: .function, characters: "\u{F70D}", charactersIgnoringModifiers: "\u{F70D}")

        controller.handleKeyDown(ctrlC)
        controller.handleKeyDown(letterA)
        controller.handleKeyDown(f10)

        XCTAssertEqual(capturedBytes.count, 3)
        XCTAssertEqual(capturedBytes[0], [0x03], "First: Ctrl+C")
        XCTAssertEqual(capturedBytes[1], [0x61], "Second: 'a'")
        XCTAssertEqual(hex(capturedBytes[2]), "1b 5b 32 31 7e", "Third: F10")
    }

    // MARK: - Pipeline: Selection is cleared on key press

    func testPipeline_KeyPressClearsSelection() throws {
        controller.selectionStart = TerminalViewController.CellPosition(col: 0, row: 0)
        controller.selectionEnd = TerminalViewController.CellPosition(col: 5, row: 0)

        let event = try makeKeyEvent(keyCode: 0, characters: "a", charactersIgnoringModifiers: "a")
        controller.handleKeyDown(event)

        XCTAssertNil(controller.selectionStart, "Selection should be cleared after key press")
        XCTAssertNil(controller.selectionEnd, "Selection should be cleared after key press")
    }
}
