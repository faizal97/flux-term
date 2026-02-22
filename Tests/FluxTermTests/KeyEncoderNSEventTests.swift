import XCTest
import AppKit
@testable import FluxTerm

// MARK: - Real NSEvent Integration Tests
//
// These tests construct real NSEvent objects via AppKit's keyEvent factory
// and verify that the full encoding pipeline produces correct terminal
// escape sequences. This catches mismatches between what macOS actually
// delivers (characters, charactersIgnoringModifiers, modifierFlags) and
// what our encoder expects.

final class KeyEncoderNSEventTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a real NSEvent.keyDown with the given parameters.
    /// Skips the test if AppKit cannot create the event (e.g. headless CI without window server).
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

    /// Encodes a real NSEvent through KeyEncoder using the event's actual properties.
    private func encodeEvent(_ event: NSEvent) -> [UInt8] {
        KeyEncoder.encode(
            keyCode: event.keyCode,
            modifiers: event.modifierFlags,
            characters: event.characters,
            charactersIgnoringModifiers: event.charactersIgnoringModifiers
        )
    }

    private func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
    }

    // MARK: - Dead-Key / IME Scenarios (Option+Letter)
    //
    // On macOS with US keyboard, Option+letter produces a "dead-key" or
    // special character in `characters`, while `charactersIgnoringModifiers`
    // returns the raw letter. Terminals must use the raw letter with ESC prefix.

    func testOptionB_DeadKey() throws {
        // Option+B: characters="∫" (integral), charsIM="b"
        let event = try makeKeyEvent(
            keyCode: 11,
            modifiers: .option,
            characters: "∫",
            charactersIgnoringModifiers: "b"
        )
        XCTAssertEqual(event.characters, "∫", "Real event should preserve dead-key character")
        XCTAssertEqual(event.charactersIgnoringModifiers, "b", "Real event should preserve raw letter")
        XCTAssertEqual(encodeEvent(event), [0x1B, 0x62], "Should produce \\eb, not UTF-8 of ∫")
    }

    func testOptionF_DeadKey() throws {
        // Option+F: characters="ƒ" (function symbol), charsIM="f"
        let event = try makeKeyEvent(
            keyCode: 3,
            modifiers: .option,
            characters: "ƒ",
            charactersIgnoringModifiers: "f"
        )
        XCTAssertEqual(encodeEvent(event), [0x1B, 0x66], "Should produce \\ef")
    }

    func testOptionD_DeadKey() throws {
        // Option+D: characters="∂" (partial derivative), charsIM="d"
        let event = try makeKeyEvent(
            keyCode: 2,
            modifiers: .option,
            characters: "∂",
            charactersIgnoringModifiers: "d"
        )
        XCTAssertEqual(encodeEvent(event), [0x1B, 0x64], "Should produce \\ed")
    }

    func testOptionE_AccentDeadKey() throws {
        // Option+E: characters="´" (acute accent dead key), charsIM="e"
        let event = try makeKeyEvent(
            keyCode: 14,
            modifiers: .option,
            characters: "´",
            charactersIgnoringModifiers: "e"
        )
        XCTAssertEqual(encodeEvent(event), [0x1B, 0x65], "Should produce \\ee, not the accent")
    }

    func testOptionU_UmlautDeadKey() throws {
        // Option+U: characters="¨" (umlaut dead key), charsIM="u"
        let event = try makeKeyEvent(
            keyCode: 32,
            modifiers: .option,
            characters: "¨",
            charactersIgnoringModifiers: "u"
        )
        XCTAssertEqual(encodeEvent(event), [0x1B, 0x75], "Should produce \\eu, not the umlaut")
    }

    func testOptionI_CircumflexDeadKey() throws {
        // Option+I: characters="ˆ" (circumflex dead key), charsIM="i"
        let event = try makeKeyEvent(
            keyCode: 34,
            modifiers: .option,
            characters: "ˆ",
            charactersIgnoringModifiers: "i"
        )
        XCTAssertEqual(encodeEvent(event), [0x1B, 0x69], "Should produce \\ei")
    }

    func testOptionN_TildeDeadKey() throws {
        // Option+N: characters="˜" (tilde dead key), charsIM="n"
        let event = try makeKeyEvent(
            keyCode: 45,
            modifiers: .option,
            characters: "˜",
            charactersIgnoringModifiers: "n"
        )
        XCTAssertEqual(encodeEvent(event), [0x1B, 0x6E], "Should produce \\en")
    }

    // MARK: - Arrow Keys with Device Flags
    //
    // Real arrow key events include .numericPad and .function in modifierFlags.
    // The encoder must not be confused by these extra device-level flags.

    func testBareLeftArrow_WithDeviceFlags() throws {
        let event = try makeKeyEvent(
            keyCode: 123,
            modifiers: [.numericPad, .function],
            characters: "\u{F702}",
            charactersIgnoringModifiers: "\u{F702}"
        )
        XCTAssertEqual(hex(encodeEvent(event)), "1b 5b 44", "Bare left arrow with device flags → \\e[D")
    }

    func testCtrlLeftArrow_WithDeviceFlags() throws {
        let event = try makeKeyEvent(
            keyCode: 123,
            modifiers: [.control, .numericPad, .function],
            characters: "\u{F702}",
            charactersIgnoringModifiers: "\u{F702}"
        )
        XCTAssertEqual(hex(encodeEvent(event)), "1b 5b 31 3b 35 44", "Ctrl+Left → \\e[1;5D")
    }

    func testShiftRightArrow_WithDeviceFlags() throws {
        let event = try makeKeyEvent(
            keyCode: 124,
            modifiers: [.shift, .numericPad, .function],
            characters: "\u{F703}",
            charactersIgnoringModifiers: "\u{F703}"
        )
        XCTAssertEqual(hex(encodeEvent(event)), "1b 5b 31 3b 32 43", "Shift+Right → \\e[1;2C")
    }

    func testAltUpArrow_WithDeviceFlags() throws {
        let event = try makeKeyEvent(
            keyCode: 126,
            modifiers: [.option, .numericPad, .function],
            characters: "\u{F700}",
            charactersIgnoringModifiers: "\u{F700}"
        )
        XCTAssertEqual(hex(encodeEvent(event)), "1b 5b 31 3b 33 41", "Alt+Up → \\e[1;3A")
    }

    func testCtrlShiftDownArrow_WithDeviceFlags() throws {
        let event = try makeKeyEvent(
            keyCode: 125,
            modifiers: [.control, .shift, .numericPad, .function],
            characters: "\u{F701}",
            charactersIgnoringModifiers: "\u{F701}"
        )
        // Shift=1, Ctrl=4 → mod=5 → param=6
        XCTAssertEqual(hex(encodeEvent(event)), "1b 5b 31 3b 36 42", "Ctrl+Shift+Down → \\e[1;6B")
    }

    func testCtrlAltShiftLeftArrow_WithDeviceFlags() throws {
        let event = try makeKeyEvent(
            keyCode: 123,
            modifiers: [.control, .option, .shift, .numericPad, .function],
            characters: "\u{F702}",
            charactersIgnoringModifiers: "\u{F702}"
        )
        // Shift=1, Alt=2, Ctrl=4 → mod=7 → param=8
        XCTAssertEqual(hex(encodeEvent(event)), "1b 5b 31 3b 38 44", "Ctrl+Alt+Shift+Left → \\e[1;8D")
    }

    // MARK: - F-Keys with Device Flags

    func testF1_WithFunctionFlag() throws {
        let event = try makeKeyEvent(
            keyCode: 122,
            modifiers: .function,
            characters: "\u{F704}",
            charactersIgnoringModifiers: "\u{F704}"
        )
        XCTAssertEqual(hex(encodeEvent(event)), "1b 4f 50", "F1 → \\eOP")
    }

    func testF10_WithFunctionFlag() throws {
        let event = try makeKeyEvent(
            keyCode: 109,
            modifiers: .function,
            characters: "\u{F70D}",
            charactersIgnoringModifiers: "\u{F70D}"
        )
        XCTAssertEqual(hex(encodeEvent(event)), "1b 5b 32 31 7e", "F10 → \\e[21~")
    }

    // MARK: - Ctrl+Letter with Real Events

    func testCtrlC_RealEvent() throws {
        let event = try makeKeyEvent(
            keyCode: 8,
            modifiers: .control,
            characters: "\u{03}",
            charactersIgnoringModifiers: "c"
        )
        XCTAssertEqual(encodeEvent(event), [0x03], "Ctrl+C → ETX (0x03)")
    }

    func testCtrlA_RealEvent() throws {
        let event = try makeKeyEvent(
            keyCode: 0,
            modifiers: .control,
            characters: "\u{01}",
            charactersIgnoringModifiers: "a"
        )
        XCTAssertEqual(encodeEvent(event), [0x01], "Ctrl+A → SOH (0x01)")
    }

    // MARK: - Shift+Tab with Real Event

    func testShiftTab_RealEvent() throws {
        let event = try makeKeyEvent(
            keyCode: 48,
            modifiers: .shift,
            characters: "\u{19}",
            charactersIgnoringModifiers: "\u{19}"
        )
        XCTAssertEqual(hex(encodeEvent(event)), "1b 5b 5a", "Shift+Tab → \\e[Z")
    }

    // MARK: - Command Key Suppression

    func testCommandA_RealEvent() throws {
        let event = try makeKeyEvent(
            keyCode: 0,
            modifiers: .command,
            characters: "a",
            charactersIgnoringModifiers: "a"
        )
        XCTAssertEqual(encodeEvent(event), [], "Cmd+A → empty (system handles)")
    }

    // MARK: - Regular Character

    func testPlainA_RealEvent() throws {
        let event = try makeKeyEvent(
            keyCode: 0,
            characters: "a",
            charactersIgnoringModifiers: "a"
        )
        XCTAssertEqual(encodeEvent(event), [0x61])
    }
}

// MARK: - Pipeline Integration Tests
//
// These test the full handleKeyDown pipeline: real NSEvent → encodeKey →
// inputInterceptor, exercising selection clearing and cursor blink reset
// alongside encoding.

final class KeyInputPipelineTests: XCTestCase {

    private var controller: TerminalViewController!
    private var capturedBytes: [[UInt8]]!

    override func setUp() {
        super.setUp()
        controller = TerminalViewController()
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

    // MARK: - Pipeline: Option+Letter (dead-key through full pipeline)

    func testPipeline_OptionB_DeadKey() throws {
        let event = try makeKeyEvent(
            keyCode: 11,
            modifiers: .option,
            characters: "∫",
            charactersIgnoringModifiers: "b"
        )
        controller.handleKeyDown(event)
        XCTAssertEqual(capturedBytes.count, 1)
        XCTAssertEqual(capturedBytes[0], [0x1B, 0x62], "Pipeline: Option+B → \\eb")
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
