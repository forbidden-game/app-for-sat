import XCTest
@testable import StudentCore

final class QuestionFeedPagingTargetIndexTests: XCTestCase {
    func testSwipeDownAdvances() {
        let target = QuestionFeedPagingTargetIndex.verticalTargetIndex(
            currentIndex: 2,
            maxIndex: 5,
            translationY: 200,
            velocityY: 0,
            pageHeight: 800
        )

        XCTAssertEqual(target, 3)
    }

    func testSwipeUpRetreats() {
        let target = QuestionFeedPagingTargetIndex.verticalTargetIndex(
            currentIndex: 2,
            maxIndex: 5,
            translationY: -200,
            velocityY: 0,
            pageHeight: 800
        )

        XCTAssertEqual(target, 1)
    }

    func testVelocityWinsWhenTranslationOpposes() {
        let target = QuestionFeedPagingTargetIndex.verticalTargetIndex(
            currentIndex: 2,
            maxIndex: 5,
            translationY: -200,
            velocityY: 1.0,
            pageHeight: 800
        )

        XCTAssertEqual(target, 3)
    }

    func testClampsAtBounds() {
        let atTop = QuestionFeedPagingTargetIndex.verticalTargetIndex(
            currentIndex: 0,
            maxIndex: 5,
            translationY: 200,
            velocityY: 0,
            pageHeight: 800
        )

        let atBottom = QuestionFeedPagingTargetIndex.verticalTargetIndex(
            currentIndex: 5,
            maxIndex: 5,
            translationY: -200,
            velocityY: 0,
            pageHeight: 800
        )

        XCTAssertEqual(atTop, 0)
        XCTAssertEqual(atBottom, 5)
    }
}
