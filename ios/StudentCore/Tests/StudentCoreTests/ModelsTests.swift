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
}
