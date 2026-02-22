import XCTest
import CoreText
@testable import FluxTerm

final class TerminalConfigTests: XCTestCase {
    func testCellSizeIsPositive() {
        var config = TerminalConfig()
        config.fontName = "Menlo"
        config.fontSize = 14

        let cell = config.cellSize
        XCTAssertGreaterThan(cell.width, 0)
        XCTAssertGreaterThan(cell.height, 0)
    }

    func testHasAnsi16Palette() {
        let config = TerminalConfig()
        XCTAssertEqual(config.colors.count, 16)
    }

    func testMenloFontSelection() {
        var config = TerminalConfig()
        config.fontName = "Menlo"
        let postScript = CTFontCopyPostScriptName(config.font) as String
        XCTAssertTrue(postScript.contains("Menlo"), "Expected Menlo font, got \(postScript)")
    }
}
