import XCTest
@testable import StudentCore

final class ScrollBoundaryTests: XCTestCase {
    func testShortContentWithInsetsIsAtTopAndBottom() {
        let state = ScrollBoundaryCalculator.calculate(
            contentHeight: 120,
            viewportHeight: 240,
            offsetY: -20,
            insetTop: 20,
            insetBottom: 12
        )

        XCTAssertFalse(state.isScrollable)
        XCTAssertTrue(state.atTop)
        XCTAssertTrue(state.atBottom)
    }
}
