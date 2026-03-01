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

    func testInitialBufferCapacityIsTracked() {
        let capacity = MetalRenderer.bufferCapacityWithHeadroom(for: 80, rows: 24)
        XCTAssertGreaterThanOrEqual(capacity, 80 * 24)
    }

    func testBufferCapacityGrowsWithHeadroom() {
        let capacity = MetalRenderer.bufferCapacityWithHeadroom(for: 500, rows: 300)
        let required = 500 * 300
        XCTAssertGreaterThanOrEqual(capacity, required)
        XCTAssertGreaterThan(capacity, required)
    }

    func testBufferCapacityHeadroomIsOnePointFive() {
        let required = 200 * 100
        let capacity = MetalRenderer.bufferCapacityWithHeadroom(for: 200, rows: 100)
        XCTAssertEqual(capacity, Int(Double(required) * 1.5))
    }

    func testBufferCapacityOverflowReturnsIntMax() {
        let capacity = MetalRenderer.bufferCapacityWithHeadroom(for: Int.max, rows: 2)
        XCTAssertEqual(capacity, Int.max)
    }
}
