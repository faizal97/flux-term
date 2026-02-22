import XCTest
import AppKit
@testable import FluxTerm

final class KeyEncoderTests: XCTestCase {

    // MARK: - Helpers

    private func encode(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags = [],
        characters: String? = nil,
        charactersIgnoringModifiers: String? = nil
    ) -> [UInt8] {
        KeyEncoder.encode(
            keyCode: keyCode,
            modifiers: modifiers,
            characters: characters,
            charactersIgnoringModifiers: charactersIgnoringModifiers
        )
    }

    /// Hex string for readable assertion messages (e.g. "1b 5b 44").
    private func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
    }

    // MARK: - Basic Keys

    func testReturn() {
        XCTAssertEqual(encode(keyCode: 36, charactersIgnoringModifiers: "\r"), [0x0D])
    }

    func testTab() {
        XCTAssertEqual(encode(keyCode: 48, charactersIgnoringModifiers: "\t"), [0x09])
    }

    func testBackspace() {
        XCTAssertEqual(encode(keyCode: 51, charactersIgnoringModifiers: "\u{7F}"), [0x7F])
    }

    func testEscape() {
        XCTAssertEqual(encode(keyCode: 53, charactersIgnoringModifiers: "\u{1B}"), [0x1B])
    }

    // MARK: - Regular Character Fallthrough

    func testRegularLetterFallsThrough() {
        let result = encode(keyCode: 0, characters: "a", charactersIgnoringModifiers: "a")
        XCTAssertEqual(result, Array("a".utf8))
    }

    func testUnicodeCharacterFallsThrough() {
        let result = encode(keyCode: 0, characters: "ñ", charactersIgnoringModifiers: "n")
        XCTAssertEqual(result, Array("ñ".utf8))
    }

    func testNilCharactersIgnoringModifiersReturnsEmpty() {
        XCTAssertEqual(encode(keyCode: 0, characters: "a", charactersIgnoringModifiers: nil), [])
    }

    // MARK: - Bare Arrow Keys

    func testLeftArrow() {
        let result = encode(keyCode: 123, charactersIgnoringModifiers: "\u{F702}")
        XCTAssertEqual(hex(result), "1b 5b 44", "Left arrow should produce \\e[D")
    }

    func testRightArrow() {
        let result = encode(keyCode: 124, charactersIgnoringModifiers: "\u{F703}")
        XCTAssertEqual(hex(result), "1b 5b 43", "Right arrow should produce \\e[C")
    }

    func testDownArrow() {
        let result = encode(keyCode: 125, charactersIgnoringModifiers: "\u{F701}")
        XCTAssertEqual(hex(result), "1b 5b 42", "Down arrow should produce \\e[B")
    }

    func testUpArrow() {
        let result = encode(keyCode: 126, charactersIgnoringModifiers: "\u{F700}")
        XCTAssertEqual(hex(result), "1b 5b 41", "Up arrow should produce \\e[A")
    }

    // MARK: - Navigation Keys

    func testHome() {
        let result = encode(keyCode: 115, charactersIgnoringModifiers: "\u{F729}")
        XCTAssertEqual(hex(result), "1b 5b 48")
    }

    func testEnd() {
        let result = encode(keyCode: 119, charactersIgnoringModifiers: "\u{F72B}")
        XCTAssertEqual(hex(result), "1b 5b 46")
    }

    func testPageUp() {
        let result = encode(keyCode: 116, charactersIgnoringModifiers: "\u{F72C}")
        XCTAssertEqual(hex(result), "1b 5b 35 7e")
    }

    func testPageDown() {
        let result = encode(keyCode: 121, charactersIgnoringModifiers: "\u{F72D}")
        XCTAssertEqual(hex(result), "1b 5b 36 7e")
    }

    func testDelete() {
        let result = encode(keyCode: 117, charactersIgnoringModifiers: "\u{F728}")
        XCTAssertEqual(hex(result), "1b 5b 33 7e")
    }

    // MARK: - F-Keys (F1–F4: SS3 format)

    func testF1() {
        let result = encode(keyCode: 122, charactersIgnoringModifiers: "\u{F704}")
        XCTAssertEqual(hex(result), "1b 4f 50", "F1 should produce \\eOP")
    }

    func testF2() {
        let result = encode(keyCode: 120, charactersIgnoringModifiers: "\u{F705}")
        XCTAssertEqual(hex(result), "1b 4f 51", "F2 should produce \\eOQ")
    }

    func testF3() {
        let result = encode(keyCode: 99, charactersIgnoringModifiers: "\u{F706}")
        XCTAssertEqual(hex(result), "1b 4f 52", "F3 should produce \\eOR")
    }

    func testF4() {
        let result = encode(keyCode: 118, charactersIgnoringModifiers: "\u{F707}")
        XCTAssertEqual(hex(result), "1b 4f 53", "F4 should produce \\eOS")
    }

    // MARK: - F-Keys (F5–F12: CSI format)

    func testF5() {
        let result = encode(keyCode: 96, charactersIgnoringModifiers: "\u{F708}")
        XCTAssertEqual(hex(result), "1b 5b 31 35 7e", "F5 should produce \\e[15~")
    }

    func testF6() {
        let result = encode(keyCode: 97, charactersIgnoringModifiers: "\u{F709}")
        XCTAssertEqual(hex(result), "1b 5b 31 37 7e", "F6 should produce \\e[17~")
    }

    func testF7() {
        let result = encode(keyCode: 98, charactersIgnoringModifiers: "\u{F70A}")
        XCTAssertEqual(hex(result), "1b 5b 31 38 7e", "F7 should produce \\e[18~")
    }

    func testF8() {
        let result = encode(keyCode: 100, charactersIgnoringModifiers: "\u{F70B}")
        XCTAssertEqual(hex(result), "1b 5b 31 39 7e", "F8 should produce \\e[19~")
    }

    func testF9() {
        let result = encode(keyCode: 101, charactersIgnoringModifiers: "\u{F70C}")
        XCTAssertEqual(hex(result), "1b 5b 32 30 7e", "F9 should produce \\e[20~")
    }

    func testF10() {
        let result = encode(keyCode: 109, charactersIgnoringModifiers: "\u{F70D}")
        XCTAssertEqual(hex(result), "1b 5b 32 31 7e", "F10 should produce \\e[21~")
    }

    func testF11() {
        let result = encode(keyCode: 103, charactersIgnoringModifiers: "\u{F70E}")
        XCTAssertEqual(hex(result), "1b 5b 32 33 7e", "F11 should produce \\e[23~")
    }

    func testF12() {
        let result = encode(keyCode: 111, charactersIgnoringModifiers: "\u{F70F}")
        XCTAssertEqual(hex(result), "1b 5b 32 34 7e", "F12 should produce \\e[24~")
    }

    // MARK: - Ctrl+Letter

    func testCtrlA() {
        let result = encode(keyCode: 0, modifiers: .control, characters: "\u{01}", charactersIgnoringModifiers: "a")
        XCTAssertEqual(result, [0x01])
    }

    func testCtrlC() {
        let result = encode(keyCode: 8, modifiers: .control, characters: "\u{03}", charactersIgnoringModifiers: "c")
        XCTAssertEqual(result, [0x03])
    }

    func testCtrlZ() {
        let result = encode(keyCode: 6, modifiers: .control, characters: "\u{1A}", charactersIgnoringModifiers: "z")
        XCTAssertEqual(result, [0x1A])
    }

    func testCtrlUppercaseLetter() {
        let result = encode(keyCode: 0, modifiers: .control, characters: "\u{01}", charactersIgnoringModifiers: "A")
        XCTAssertEqual(result, [0x01])
    }

    // MARK: - Shift+Tab

    func testShiftTab() {
        let result = encode(keyCode: 48, modifiers: .shift, characters: "\u{19}", charactersIgnoringModifiers: "\u{19}")
        XCTAssertEqual(hex(result), "1b 5b 5a", "Shift+Tab should produce \\e[Z")
    }

    // MARK: - Modifier+Arrow Keys

    func testShiftLeftArrow() {
        let result = encode(keyCode: 123, modifiers: .shift, charactersIgnoringModifiers: "\u{F702}")
        XCTAssertEqual(hex(result), "1b 5b 31 3b 32 44", "Shift+Left should produce \\e[1;2D")
    }

    func testShiftRightArrow() {
        let result = encode(keyCode: 124, modifiers: .shift, charactersIgnoringModifiers: "\u{F703}")
        XCTAssertEqual(hex(result), "1b 5b 31 3b 32 43", "Shift+Right should produce \\e[1;2C")
    }

    func testCtrlLeftArrow() {
        let result = encode(keyCode: 123, modifiers: .control, charactersIgnoringModifiers: "\u{F702}")
        XCTAssertEqual(hex(result), "1b 5b 31 3b 35 44", "Ctrl+Left should produce \\e[1;5D")
    }

    func testCtrlRightArrow() {
        let result = encode(keyCode: 124, modifiers: .control, charactersIgnoringModifiers: "\u{F703}")
        XCTAssertEqual(hex(result), "1b 5b 31 3b 35 43", "Ctrl+Right should produce \\e[1;5C")
    }

    func testAltLeftArrow() {
        let result = encode(keyCode: 123, modifiers: .option, charactersIgnoringModifiers: "\u{F702}")
        XCTAssertEqual(hex(result), "1b 5b 31 3b 33 44", "Alt+Left should produce \\e[1;3D")
    }

    func testAltUpArrow() {
        let result = encode(keyCode: 126, modifiers: .option, charactersIgnoringModifiers: "\u{F700}")
        XCTAssertEqual(hex(result), "1b 5b 31 3b 33 41", "Alt+Up should produce \\e[1;3A")
    }

    func testAltDownArrow() {
        let result = encode(keyCode: 125, modifiers: .option, charactersIgnoringModifiers: "\u{F701}")
        XCTAssertEqual(hex(result), "1b 5b 31 3b 33 42", "Alt+Down should produce \\e[1;3B")
    }

    // MARK: - Combined Modifier+Arrow Keys

    func testCtrlShiftLeftArrow() {
        let result = encode(keyCode: 123, modifiers: [.control, .shift], charactersIgnoringModifiers: "\u{F702}")
        // Shift=1, Ctrl=4 → mod=5 → param=6
        XCTAssertEqual(hex(result), "1b 5b 31 3b 36 44", "Ctrl+Shift+Left should produce \\e[1;6D")
    }

    func testAltShiftRightArrow() {
        let result = encode(keyCode: 124, modifiers: [.option, .shift], charactersIgnoringModifiers: "\u{F703}")
        // Shift=1, Alt=2 → mod=3 → param=4
        XCTAssertEqual(hex(result), "1b 5b 31 3b 34 43", "Alt+Shift+Right should produce \\e[1;4C")
    }

    func testCtrlAltLeftArrow() {
        let result = encode(keyCode: 123, modifiers: [.control, .option], charactersIgnoringModifiers: "\u{F702}")
        // Alt=2, Ctrl=4 → mod=6 → param=7
        XCTAssertEqual(hex(result), "1b 5b 31 3b 37 44", "Ctrl+Alt+Left should produce \\e[1;7D")
    }

    func testCtrlAltShiftUpArrow() {
        let result = encode(keyCode: 126, modifiers: [.control, .option, .shift], charactersIgnoringModifiers: "\u{F700}")
        // Shift=1, Alt=2, Ctrl=4 → mod=7 → param=8
        XCTAssertEqual(hex(result), "1b 5b 31 3b 38 41", "Ctrl+Alt+Shift+Up should produce \\e[1;8A")
    }

    // MARK: - Alt/Option+Letter

    func testAltB() {
        let result = encode(keyCode: 11, modifiers: .option, characters: "∫", charactersIgnoringModifiers: "b")
        XCTAssertEqual(result, [0x1B, 0x62], "Alt+B should produce \\eb")
    }

    func testAltF() {
        let result = encode(keyCode: 3, modifiers: .option, characters: "ƒ", charactersIgnoringModifiers: "f")
        XCTAssertEqual(result, [0x1B, 0x66], "Alt+F should produce \\ef")
    }

    func testAltD() {
        let result = encode(keyCode: 2, modifiers: .option, characters: "∂", charactersIgnoringModifiers: "d")
        XCTAssertEqual(result, [0x1B, 0x64], "Alt+D should produce \\ed")
    }

    func testAltPeriod() {
        let result = encode(keyCode: 47, modifiers: .option, characters: "≥", charactersIgnoringModifiers: ".")
        XCTAssertEqual(result, [0x1B, 0x2E], "Alt+. should produce \\e.")
    }

    // MARK: - Alt/Option+Letter: Layout Independence
    //
    // `characters` varies by keyboard layout (US: "∫", German: "ß", etc.).
    // The encoder must always use `charactersIgnoringModifiers` instead.

    func testOptionLetterIgnoresCharactersValue() {
        // Same key+modifier, different characters values from different layouts
        let cases: [(UInt16, String, String)] = [
            (11, "b", "∫"),     // US
            (11, "b", "ß"),     // German
            (11, "b", "∏"),     // hypothetical
            (3,  "f", "ƒ"),     // US
            (3,  "f", "·"),     // hypothetical
            (2,  "d", "∂"),     // US
            (14, "e", "´"),     // US: acute accent dead key
            (32, "u", "¨"),     // US: umlaut dead key
            (34, "i", "ˆ"),     // US: circumflex dead key
            (45, "n", "˜"),     // US: tilde dead key
        ]
        for (keyCode, rawLetter, layoutChars) in cases {
            let expected: [UInt8] = [0x1B, UInt8(rawLetter.unicodeScalars.first!.value)]
            let result = encode(
                keyCode: keyCode,
                modifiers: .option,
                characters: layoutChars,
                charactersIgnoringModifiers: rawLetter
            )
            XCTAssertEqual(result, expected,
                "Option+\(rawLetter) with characters=\"\(layoutChars)\" should produce \\e\(rawLetter)")
        }
    }

    func testOptionBOutputIdenticalAcrossLayouts() {
        let expected: [UInt8] = [0x1B, 0x62]
        for layoutChars in ["∫", "ß", "β", "♭"] {
            let result = encode(
                keyCode: 11,
                modifiers: .option,
                characters: layoutChars,
                charactersIgnoringModifiers: "b"
            )
            XCTAssertEqual(result, expected,
                "Option+b with characters=\"\(layoutChars)\" should still produce \\eb")
        }
    }

    // MARK: - Device-Level Modifier Flags
    //
    // Real arrow/F-key events include .numericPad and .function in modifierFlags.
    // The encoder must not treat these as Shift/Ctrl/Alt modifiers.

    func testBareArrowWithDeviceFlags() {
        let result = encode(keyCode: 123, modifiers: [.numericPad, .function], charactersIgnoringModifiers: "\u{F702}")
        XCTAssertEqual(hex(result), "1b 5b 44", "Bare left with .numericPad/.function → \\e[D")
    }

    func testCtrlArrowWithDeviceFlags() {
        let result = encode(keyCode: 123, modifiers: [.control, .numericPad, .function], charactersIgnoringModifiers: "\u{F702}")
        XCTAssertEqual(hex(result), "1b 5b 31 3b 35 44", "Ctrl+Left with device flags → \\e[1;5D")
    }

    func testShiftArrowWithDeviceFlags() {
        let result = encode(keyCode: 124, modifiers: [.shift, .numericPad, .function], charactersIgnoringModifiers: "\u{F703}")
        XCTAssertEqual(hex(result), "1b 5b 31 3b 32 43", "Shift+Right with device flags → \\e[1;2C")
    }

    func testCtrlShiftArrowWithDeviceFlags() {
        let result = encode(keyCode: 125, modifiers: [.control, .shift, .numericPad, .function], charactersIgnoringModifiers: "\u{F701}")
        XCTAssertEqual(hex(result), "1b 5b 31 3b 36 42", "Ctrl+Shift+Down with device flags → \\e[1;6B")
    }

    func testCtrlAltShiftArrowWithDeviceFlags() {
        let result = encode(keyCode: 123, modifiers: [.control, .option, .shift, .numericPad, .function], charactersIgnoringModifiers: "\u{F702}")
        XCTAssertEqual(hex(result), "1b 5b 31 3b 38 44", "Ctrl+Alt+Shift+Left with device flags → \\e[1;8D")
    }

    func testFKeyWithFunctionFlag() {
        let f1 = encode(keyCode: 122, modifiers: .function, charactersIgnoringModifiers: "\u{F704}")
        XCTAssertEqual(hex(f1), "1b 4f 50", "F1 with .function flag → \\eOP")

        let f10 = encode(keyCode: 109, modifiers: .function, charactersIgnoringModifiers: "\u{F70D}")
        XCTAssertEqual(hex(f10), "1b 5b 32 31 7e", "F10 with .function flag → \\e[21~")
    }

    // MARK: - Command Suppression

    func testCommandKeySuppressed() {
        let result = encode(keyCode: 0, modifiers: .command, characters: "a", charactersIgnoringModifiers: "a")
        XCTAssertEqual(result, [], "Cmd+key should return empty (handled by system)")
    }

    func testCommandShiftSuppressed() {
        let result = encode(keyCode: 0, modifiers: [.command, .shift], characters: "A", charactersIgnoringModifiers: "a")
        XCTAssertEqual(result, [], "Cmd+Shift+key should return empty")
    }

    // MARK: - Edge Cases

    func testAltNonASCIIKeyFallsThrough() {
        // Alt + a key where charactersIgnoringModifiers is non-ASCII (shouldn't happen
        // in practice, but verifies the isASCII guard)
        let result = encode(keyCode: 0, modifiers: .option, characters: "ø", charactersIgnoringModifiers: "ø")
        // Falls through to characters fallback
        XCTAssertEqual(result, Array("ø".utf8))
    }

    func testCtrlWithNonLetterFallsThrough() {
        // Ctrl+[ (keyCode 33) — scalar value 0x5B is outside Ctrl letter range
        let result = encode(keyCode: 33, modifiers: .control, characters: "\u{1B}", charactersIgnoringModifiers: "[")
        // '[' is 0x5B, above 0x5A, so ctrl handler doesn't match; falls through to characters
        XCTAssertEqual(result, [0x1B])
    }

    func testCtrlArrowDoesNotProduceControlCode() {
        // Arrow function key Unicode (0xF702) is far outside the a-z/A-Z range,
        // so the ctrl+letter handler must NOT intercept it
        let result = encode(keyCode: 123, modifiers: .control, charactersIgnoringModifiers: "\u{F702}")
        XCTAssertEqual(hex(result), "1b 5b 31 3b 35 44", "Ctrl+Left should be arrow, not ctrl code")
    }

    func testNilCharactersWithSpecialKeyStillWorks() {
        // F1 with nil characters — should still encode via keyCode
        let result = encode(keyCode: 122, characters: nil, charactersIgnoringModifiers: "\u{F704}")
        XCTAssertEqual(hex(result), "1b 4f 50")
    }
}
