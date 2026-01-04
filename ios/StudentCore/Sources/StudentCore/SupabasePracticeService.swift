import Foundation
import Supabase

public struct PracticeSessionRow: Decodable {
    public let id: UUID
}

public final class SupabasePracticeService {
    private let client: SupabaseClient

    public init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    public func fetchQuestions(limit: Int) async throws -> [Question] {
        struct DBQuestion: Decodable {
            let id: UUID
            let question_type: String
            let stem: String
            let answer_key: AnswerKey
            let question_options: [QuestionOption]?
        }

        let rows: [DBQuestion] = try await client
            .from("questions")
            .select("id, question_type, stem, answer_key, question_options(label, content)")
            .limit(limit)
            .execute()
            .value

        return rows.map { row in
            let options = row.question_options?.sorted(by: { $0.label < $1.label })
            return Question(
                id: row.id.uuidString,
                questionType: row.question_type,
                stem: row.stem,
                options: options,
                answerKey: row.answer_key
            )
        }
    }

    public func createSession(studentId: String, totalQuestions: Int) async throws -> String {
        struct SessionInsert: Encodable {
            let student_id: UUID
            let total_questions: Int
            let correct_count: Int
            let mode: String
        }

        let studentUUID = UUID(uuidString: studentId) ?? UUID()
        let insert = SessionInsert(student_id: studentUUID, total_questions: totalQuestions, correct_count: 0, mode: "practice")

        let created: PracticeSessionRow = try await client
            .from("sessions")
            .insert(insert)
            .select("id")
            .single()
            .execute()
            .value

        return created.id.uuidString
    }

    public func submitAttempt(question: Question, answer: String, sessionId: String, studentId: String) async throws -> Bool {
        let payload = FunctionPayload(
            question: FunctionQuestion(questionType: question.questionType, answerKey: FunctionAnswerKey(correct: question.answerKey)),
            attempt: FunctionAttempt(answer: encodedAnswer(for: question, answer: answer))
        )

        struct FunctionResponse: Decodable {
            let isCorrect: Bool
        }

        let response: FunctionResponse = try await client.functions
            .invoke("submit_attempt", options: FunctionInvokeOptions(body: payload))

        try await insertAttempt(
            questionId: question.id,
            sessionId: sessionId,
            studentId: studentId,
            answer: answer,
            isCorrect: response.isCorrect
        )

        return response.isCorrect
    }

    public func updateSession(sessionId: String, totalQuestions: Int, correctCount: Int) async throws {
        struct SessionUpdate: Encodable {
            let total_questions: Int
            let correct_count: Int
        }

        let update = SessionUpdate(total_questions: totalQuestions, correct_count: correctCount)
        try await client
            .from("sessions")
            .update(update)
            .eq("id", value: sessionId)
            .execute()
    }

    private func insertAttempt(questionId: String, sessionId: String, studentId: String, answer: String, isCorrect: Bool) async throws {
        struct AttemptInsert: Encodable {
            let session_id: UUID
            let question_id: UUID
            let student_id: UUID
            let answer: String
            let is_correct: Bool
            let skipped: Bool
        }

        guard let sessionUUID = UUID(uuidString: sessionId),
              let questionUUID = UUID(uuidString: questionId),
              let studentUUID = UUID(uuidString: studentId) else {
            return
        }

        let insert = AttemptInsert(
            session_id: sessionUUID,
            question_id: questionUUID,
            student_id: studentUUID,
            answer: answer,
            is_correct: isCorrect,
            skipped: false
        )

        try await client
            .from("attempts")
            .insert(insert)
            .execute()
    }

    private func encodedAnswer(for question: Question, answer: String) -> FunctionAnswerValue? {
        if question.questionType == "numeric", let value = Double(answer) {
            return .number(value)
        }
        if answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }
        return .string(answer)
    }
}

private struct FunctionPayload: Encodable {
    let question: FunctionQuestion
    let attempt: FunctionAttempt
}

private struct FunctionQuestion: Encodable {
    let questionType: String
    let answerKey: FunctionAnswerKey
}

private struct FunctionAnswerKey: Encodable {
    let correct: FunctionAnswerValue?

    init(correct: AnswerKey) {
        if let s = correct.correctString {
            self.correct = .string(s)
        } else if let n = correct.correctNumber {
            self.correct = .number(n)
        } else {
            self.correct = nil
        }
    }
}

private struct FunctionAttempt: Encodable {
    let answer: FunctionAnswerValue?
}

private enum FunctionAnswerValue: Encodable {
    case string(String)
    case number(Double)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        }
    }
}
