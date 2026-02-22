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

    func testInitializationErrorPipelineMessageIncludesContext() {
        let underlying = NSError(
            domain: "FluxTermTests",
            code: 42,
            userInfo: [NSLocalizedDescriptionKey: "mock shader compile failure"]
        )
        let error = MetalRenderer.InitializationError.pipelineCreationFailed(
            name: "glyph",
            underlying: underlying
        )

        XCTAssertTrue(error.localizedDescription.contains("glyph"))
        XCTAssertTrue(error.localizedDescription.contains("mock shader compile failure"))
    }
}
