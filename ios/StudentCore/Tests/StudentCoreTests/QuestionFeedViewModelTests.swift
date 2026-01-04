import XCTest
@testable import StudentCore

final class QuestionFeedViewModelTests: XCTestCase {
    func testAdvanceMovesIndex() async throws {
        let session = PracticeSession(id: "S1", questions: [
            Question(id: "Q1", questionType: "mcq", stem: "A?", options: nil, answerKey: AnswerKey(correct: "A")),
            Question(id: "Q2", questionType: "mcq", stem: "B?", options: nil, answerKey: AnswerKey(correct: "B"))
        ])
        let vm = QuestionFeedViewModel(session: session)
        XCTAssertEqual(vm.currentIndex, 0)
        vm.advance()
        XCTAssertEqual(vm.currentIndex, 1)
    }

    func testRetreatMovesIndex() async throws {
        let session = PracticeSession(id: "S1", questions: [
            Question(id: "Q1", questionType: "mcq", stem: "A?", options: nil, answerKey: AnswerKey(correct: "A")),
            Question(id: "Q2", questionType: "mcq", stem: "B?", options: nil, answerKey: AnswerKey(correct: "B"))
        ])
        let vm = QuestionFeedViewModel(session: session)
        vm.advance()
        XCTAssertEqual(vm.currentIndex, 1)
        vm.retreat()
        XCTAssertEqual(vm.currentIndex, 0)
    }

    func testJumpMovesIndex() async throws {
        let session = PracticeSession(id: "S1", questions: [
            Question(id: "Q1", questionType: "mcq", stem: "A?", options: nil, answerKey: AnswerKey(correct: "A")),
            Question(id: "Q2", questionType: "mcq", stem: "B?", options: nil, answerKey: AnswerKey(correct: "B"))
        ])
        let vm = QuestionFeedViewModel(session: session)
        vm.jump(to: 1)
        XCTAssertEqual(vm.currentIndex, 1)
        vm.jump(to: 0)
        XCTAssertEqual(vm.currentIndex, 0)
    }
}
