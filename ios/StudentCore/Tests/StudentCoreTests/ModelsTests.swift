import XCTest
@testable import StudentCore

final class ModelsTests: XCTestCase {
    func testQuestionDecodeMCQ() throws {
        let json = #"{"id":"Q1","questionType":"mcq","stem":"2+2?","options":[{"label":"A","content":"3"},{"label":"B","content":"4"}],"answerKey":{"correct":"B"}}"#
        let data = json.data(using: .utf8)!
        let q = try JSONDecoder().decode(Question.self, from: data)
        XCTAssertEqual(q.options?.count, 2)
        XCTAssertEqual(q.answerKey?.correctString, "B")
    }

    func testSessionResultDecodeIncludesAttemptId() throws {
        let json = #"{"session_id":"S1","total_questions":1,"correct_count":0,"questions":[{"question_id":"Q1","attempt_id":"A1","position":1,"is_correct":false,"user_answer":"A","correct_answer":"B","stem":"2+2?","options":[{"label":"A","content":"3"},{"label":"B","content":"4"}],"explanation":"check"}]}"#
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(SessionResult.self, from: data)
        XCTAssertEqual(result.questions.first?.attemptId, "A1")
    }
}
