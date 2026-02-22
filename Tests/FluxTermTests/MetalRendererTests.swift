import XCTest
@testable import FluxTerm

final class MetalRendererTests: XCTestCase {
    func testGridSizeUsesPointSpace() throws {
        let cellWidth: Float = 9
        let cellHeight: Float = 18
        let padding: CGFloat = 8
        let width = CGFloat(cellWidth * 80) + padding * 2 + 1
        let height = CGFloat(cellHeight * 24) + padding * 2 + 1

        let grid = MetalRenderer.computeGridSize(
            viewSize: CGSize(width: width, height: height),
            padding: padding,
            cellWidth: cellWidth,
            cellHeight: cellHeight
        )
        XCTAssertEqual(grid.cols, 80)
        XCTAssertEqual(grid.rows, 24)
    }
}
