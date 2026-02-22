import AppKit
import CoreText

struct TerminalConfig {
    var fontName: String = "JetBrainsMono-Regular"
    var fontSize: CGFloat = 14.5
    var backgroundOpacity: Float = 0.78
    var padding: CGFloat = 14.0
    var lineSpacingMultiplier: CGFloat = 1.15

    var foregroundColor: SIMD4<Float> = SIMD4<Float>(0.804, 0.839, 0.957, 1.0)  // #CDD6F4
    var backgroundColor: SIMD4<Float> = SIMD4<Float>(0.118, 0.118, 0.180, 1.0)  // #1E1E2E
    var cursorColor: SIMD4<Float> = SIMD4<Float>(0.961, 0.878, 0.863, 0.90)  // #F5E0DC
    var urlColor: SIMD4<Float> = SIMD4<Float>(0.537, 0.706, 0.980, 1.0)  // #89B4FA
    var selectionColor: SIMD4<Float> = SIMD4<Float>(0.192, 0.196, 0.267, 0.70)  // #313244 @ 70%

    var colors: [SIMD4<Float>] = [
        // Normal colors (0-7)
        SIMD4<Float>(0.271, 0.278, 0.353, 1.0),  // 0 black   #45475A
        SIMD4<Float>(0.953, 0.545, 0.659, 1.0),  // 1 red     #F38BA8
        SIMD4<Float>(0.651, 0.890, 0.631, 1.0),  // 2 green   #A6E3A1
        SIMD4<Float>(0.976, 0.886, 0.686, 1.0),  // 3 yellow  #F9E2AF
        SIMD4<Float>(0.537, 0.706, 0.980, 1.0),  // 4 blue    #89B4FA
        SIMD4<Float>(0.961, 0.761, 0.906, 1.0),  // 5 magenta #F5C2E7
        SIMD4<Float>(0.580, 0.886, 0.835, 1.0),  // 6 cyan    #94E2D5
        SIMD4<Float>(0.729, 0.761, 0.871, 1.0),  // 7 white   #BAC2DE
        // Bright colors (8-15)
        SIMD4<Float>(0.345, 0.357, 0.439, 1.0),  // 8  bright black   #585B70
        SIMD4<Float>(0.953, 0.545, 0.659, 1.0),  // 9  bright red     #F38BA8
        SIMD4<Float>(0.651, 0.890, 0.631, 1.0),  // 10 bright green   #A6E3A1
        SIMD4<Float>(0.976, 0.886, 0.686, 1.0),  // 11 bright yellow  #F9E2AF
        SIMD4<Float>(0.537, 0.706, 0.980, 1.0),  // 12 bright blue    #89B4FA
        SIMD4<Float>(0.796, 0.651, 0.969, 1.0),  // 13 bright magenta #CBA6F7 (Mauve)
        SIMD4<Float>(0.580, 0.886, 0.835, 1.0),  // 14 bright cyan    #94E2D5
        SIMD4<Float>(0.651, 0.678, 0.784, 1.0)  // 15 bright white   #A6ADC8
    ]

    var font: CTFont {
        // Try JetBrains Mono first.
        if let exact = NSFont(name: fontName, size: fontSize) {
            return exact as CTFont
        }
        // Fallback to MesloLGS NF (has Nerd Font icons).
        if let meslo = NSFont(name: "MesloLGS NF", size: fontSize) {
            return meslo as CTFont
        }
        // Fallback to Menlo (always available on macOS).
        if let menlo = NSFont(name: "Menlo", size: fontSize) {
            return menlo as CTFont
        }
        return CTFontCreateWithName("Menlo" as CFString, fontSize, nil)
    }

    var cellSize: CGSize {
        let f = font
        let advance = glyphAdvance(for: "W", in: f)
        let lineHeight = CTFontGetAscent(f) + CTFontGetDescent(f) + CTFontGetLeading(f)
        return CGSize(
            width: max(1, advance),
            height: max(1, ceil(lineHeight * lineSpacingMultiplier))
        )
    }

    private func glyphAdvance(for char: Character, in font: CTFont) -> CGFloat {
        var chars: [UniChar] = Array(String(char).utf16)
        var glyph: CGGlyph = 0
        CTFontGetGlyphsForCharacters(font, &chars, &glyph, 1)
        var advance = CGSize.zero
        CTFontGetAdvancesForGlyphs(font, .default, &glyph, &advance, 1)
        return advance.width
    }
}
