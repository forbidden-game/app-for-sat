import XCTest
@testable import StudentCore

final class QuestionFeedPagingTargetIndexTests: XCTestCase {
    func testSwipeDownRetreats() {
        let target = QuestionFeedPagingTargetIndex.verticalTargetIndex(
            currentIndex: 2,
            maxIndex: 5,
            proposedIndex: 1,
            translationY: 200,
            velocityY: 0,
            pageHeight: 800
        )

        XCTAssertEqual(target, 1)
    }

    func testSwipeUpAdvances() {
        let target = QuestionFeedPagingTargetIndex.verticalTargetIndex(
            currentIndex: 2,
            maxIndex: 5,
            proposedIndex: 3,
            translationY: -200,
            velocityY: 0,
            pageHeight: 800
        )

        XCTAssertEqual(target, 3)
    }

    func testTranslationWinsWhenDirectionOpposes() {
        let target = QuestionFeedPagingTargetIndex.verticalTargetIndex(
            currentIndex: 2,
            maxIndex: 5,
            proposedIndex: 3,
            translationY: 200,
            velocityY: -1.0,
            pageHeight: 800
        )

        XCTAssertEqual(target, 3)
    }

    func testClampsAtBounds() {
        let atTop = QuestionFeedPagingTargetIndex.verticalTargetIndex(
            currentIndex: 0,
            maxIndex: 5,
            proposedIndex: -1,
            translationY: 200,
            velocityY: 0,
            pageHeight: 800
        )

        let atBottom = QuestionFeedPagingTargetIndex.verticalTargetIndex(
            currentIndex: 5,
            maxIndex: 5,
            proposedIndex: 6,
            translationY: -200,
            velocityY: 0,
            pageHeight: 800
        )

        XCTAssertEqual(atTop, 0)
        XCTAssertEqual(atBottom, 5)
    }

    func testBelowThresholdKeepsCurrentIndex() {
        let target = QuestionFeedPagingTargetIndex.verticalTargetIndex(
            currentIndex: 2,
            maxIndex: 5,
            proposedIndex: 3,
            translationY: 10,
            velocityY: 0.1,
            pageHeight: 800
        )

        XCTAssertEqual(target, 2)
    }
}
