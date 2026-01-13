import XCTest
@testable import StudentCore

final class QuestionTextDeriverTests: XCTestCase {
    func testDeriveReturnsPromptOnlyWhenNoPassage() {
        let stem = "2 + 2 = ?"
        let derived = QuestionTextDeriver.derive(from: stem)
        XCTAssertEqual(derived.prompt, "2 + 2 = ?")
        XCTAssertNil(derived.passage)
    }

    func testDeriveExtractsShortStimulusAsPassage() {
        let stem = "Solar panels convert sunlight into electricity and reduce reliance on fossil fuels. Which choice best states the main idea of the sentence?"
        let derived = QuestionTextDeriver.derive(from: stem)
        XCTAssertEqual(derived.prompt, "Which choice best states the main idea of the sentence?")
        XCTAssertEqual(
            derived.passage,
            "Solar panels convert sunlight into electricity and reduce reliance on fossil fuels."
        )
    }

    func testDeriveExtractsTrailingQuestionSentenceAsPrompt() {
        let passage = Array(repeating: "This is a long passage sentence.", count: 12).joined(separator: " ")
        let stem = passage + " What is the main idea?"

        let derived = QuestionTextDeriver.derive(from: stem)
        XCTAssertEqual(derived.prompt, "What is the main idea?")
        XCTAssertEqual(derived.passage, passage)
    }

    func testDeriveUsesLastQuestionMark() {
        let passage = Array(repeating: "Another long passage sentence.", count: 12).joined(separator: " ")
        let stem = passage + " What is asked first? What is asked last?"

        let derived = QuestionTextDeriver.derive(from: stem)
        XCTAssertEqual(derived.prompt, "What is asked last?")
        XCTAssertEqual(derived.passage, passage + " What is asked first?")
    }
}
