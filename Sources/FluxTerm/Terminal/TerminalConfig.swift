import AppKit
import CoreText

struct TerminalConfig {
    var fontName: String = "MesloLGS NF"
    var fontSize: CGFloat = 14.0
    var backgroundOpacity: Float = 0.85
    var padding: CGFloat = 8.0

    var foregroundColor: SIMD4<Float> = SIMD4<Float>(0.847, 0.871, 0.914, 1.0)
    var backgroundColor: SIMD4<Float> = SIMD4<Float>(0.18, 0.204, 0.251, 1.0)
    var cursorColor: SIMD4<Float> = SIMD4<Float>(0.847, 0.871, 0.914, 0.80)
    var urlColor: SIMD4<Float> = SIMD4<Float>(0.56, 0.78, 0.99, 1.0)

    var colors: [SIMD4<Float>] = [
        SIMD4<Float>(0.231, 0.259, 0.322, 1.0),
        SIMD4<Float>(0.749, 0.380, 0.416, 1.0),
        SIMD4<Float>(0.631, 0.757, 0.549, 1.0),
        SIMD4<Float>(0.922, 0.796, 0.545, 1.0),
        SIMD4<Float>(0.506, 0.631, 0.757, 1.0),
        SIMD4<Float>(0.706, 0.557, 0.678, 1.0),
        SIMD4<Float>(0.533, 0.753, 0.816, 1.0),
        SIMD4<Float>(0.898, 0.914, 0.941, 1.0),
        SIMD4<Float>(0.298, 0.337, 0.416, 1.0),
        SIMD4<Float>(0.749, 0.380, 0.416, 1.0),
        SIMD4<Float>(0.631, 0.757, 0.549, 1.0),
        SIMD4<Float>(0.922, 0.796, 0.545, 1.0),
        SIMD4<Float>(0.506, 0.631, 0.757, 1.0),
        SIMD4<Float>(0.706, 0.557, 0.678, 1.0),
        SIMD4<Float>(0.557, 0.773, 0.831, 1.0),
        SIMD4<Float>(0.925, 0.937, 0.957, 1.0)
    ]

    var font: CTFont {
        if let exact = NSFont(name: fontName, size: fontSize) {
            return exact as CTFont
        }
        if let menlo = NSFont(name: "Menlo", size: fontSize) {
            return menlo as CTFont
        }
        return CTFontCreateWithName("Menlo" as CFString, fontSize, nil)
    }

    var cellSize: CGSize {
        let f = font
        let advance = glyphAdvance(for: "W", in: f)
        let lineHeight = CTFontGetAscent(f) + CTFontGetDescent(f) + CTFontGetLeading(f)
        return CGSize(width: max(1, advance), height: max(1, ceil(lineHeight)))
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
