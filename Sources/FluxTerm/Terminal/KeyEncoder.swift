import AppKit

struct KeyEncoder {
    static func encode(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        characters: String?,
        charactersIgnoringModifiers: String?
    ) -> [UInt8] {
        guard let chars = charactersIgnoringModifiers else { return [] }

        if modifiers.contains(.command) {
            return []
        }

        // Ctrl+letter → control codes
        if modifiers.contains(.control), let scalar = chars.unicodeScalars.first {
            let code = scalar.value
            if code >= 0x61 && code <= 0x7A {
                return [UInt8(code - 0x60)]
            }
            if code >= 0x41 && code <= 0x5A {
                return [UInt8(code - 0x40)]
            }
        }

        // Shift+Tab → back-tab
        if keyCode == 48 && modifiers.contains(.shift) {
            return [0x1B, 0x5B, 0x5A]
        }

        switch keyCode {
        case 36: return [0x0D]                                    // Return
        case 48: return [0x09]                                    // Tab
        case 51: return [0x7F]                                    // Backspace
        case 53: return [0x1B]                                    // Escape
        case 123: return arrowKey(0x44, modifiers)                // Left
        case 124: return arrowKey(0x43, modifiers)                // Right
        case 125: return arrowKey(0x42, modifiers)                // Down
        case 126: return arrowKey(0x41, modifiers)                // Up
        case 115: return [0x1B, 0x5B, 0x48]                      // Home
        case 119: return [0x1B, 0x5B, 0x46]                      // End
        case 116: return [0x1B, 0x5B, 0x35, 0x7E]                // PageUp
        case 121: return [0x1B, 0x5B, 0x36, 0x7E]                // PageDown
        case 117: return [0x1B, 0x5B, 0x33, 0x7E]                // Delete
        case 122: return [0x1B, 0x4F, 0x50]                      // F1
        case 120: return [0x1B, 0x4F, 0x51]                      // F2
        case 99:  return [0x1B, 0x4F, 0x52]                      // F3
        case 118: return [0x1B, 0x4F, 0x53]                      // F4
        case 96:  return [0x1B, 0x5B, 0x31, 0x35, 0x7E]          // F5
        case 97:  return [0x1B, 0x5B, 0x31, 0x37, 0x7E]          // F6
        case 98:  return [0x1B, 0x5B, 0x31, 0x38, 0x7E]          // F7
        case 100: return [0x1B, 0x5B, 0x31, 0x39, 0x7E]          // F8
        case 101: return [0x1B, 0x5B, 0x32, 0x30, 0x7E]          // F9
        case 109: return [0x1B, 0x5B, 0x32, 0x31, 0x7E]          // F10
        case 103: return [0x1B, 0x5B, 0x32, 0x33, 0x7E]          // F11
        case 111: return [0x1B, 0x5B, 0x32, 0x34, 0x7E]          // F12
        default: break
        }

        // Alt/Option+key → ESC prefix
        if modifiers.contains(.option), let scalar = chars.unicodeScalars.first, scalar.isASCII {
            return [0x1B, UInt8(scalar.value)]
        }

        if let text = characters {
            return Array(text.utf8)
        }
        return []
    }

    private static func arrowKey(_ direction: UInt8, _ flags: NSEvent.ModifierFlags) -> [UInt8] {
        var mod = 0
        if flags.contains(.shift) { mod |= 1 }
        if flags.contains(.option) { mod |= 2 }
        if flags.contains(.control) { mod |= 4 }
        if mod == 0 {
            return [0x1B, 0x5B, direction]
        }
        return [0x1B, 0x5B, 0x31, 0x3B, UInt8(0x30 + mod + 1), direction]
    }
}
