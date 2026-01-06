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

    public func fetchQuestionBanks() async throws -> [QuestionBank] {
        struct BankRow: Decodable {
            let id: UUID
            let slug: String
            let title: String
            let subtitle: String?
            let icon: String?
            let mode: String
            let question_limit: Int
            let sort_order: Int
        }

        let rows: [BankRow] = try await client
            .from("question_banks")
            .select("id, slug, title, subtitle, icon, mode, question_limit, sort_order")
            .eq("is_active", value: true)
            .order("sort_order", ascending: true)
            .execute()
            .value

        return rows.map { row in
            QuestionBank(
                id: row.id.uuidString,
                slug: row.slug,
                title: row.title,
                subtitle: row.subtitle,
                icon: row.icon,
                mode: row.mode,
                questionLimit: row.question_limit,
                sortOrder: row.sort_order
            )
        }
    }

    public func startPracticeSession(bankSlug: String, overrideLimit: Int? = nil) async throws -> PracticeSession {
        let params = StartPracticeSessionParams(bank_slug: bankSlug, override_limit: overrideLimit)
        let response: StartPracticeSessionResponse = try await client
            .rpc("start_practice_session", params: params)
            .execute()
            .value

        let questions = response.questions.map { payload in
            Question(
                id: payload.id,
                questionType: payload.questionType,
                stem: payload.stem,
                options: payload.options,
                answerKey: nil
            )
        }

        return PracticeSession(id: response.sessionId, questions: questions)
    }

    public func fetchQuestions(limit: Int) async throws -> [Question] {
        struct DBQuestion: Decodable {
            let id: UUID
            let question_type: String
            let stem: String
            let answer_key: AnswerKey?
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

    public func submitAttempt(
        question: Question,
        answer: String?,
        sessionId: String,
        durationMs: Int? = nil,
        skipped: Bool? = nil
    ) async throws -> Bool {
        let payload = SubmitAttemptPayload(
            session_id: sessionId,
            question_id: question.id,
            answer: encodedAnswer(for: question, answer: answer),
            duration_ms: durationMs,
            skipped: skipped
        )

        struct FunctionResponse: Decodable {
            let isCorrect: Bool
        }

        let response: FunctionResponse = try await client.functions
            .invoke("submit_attempt", options: FunctionInvokeOptions(body: payload))

        return response.isCorrect
    }

    public func fetchSessionResult(sessionId: String) async throws -> SessionResult {
        struct Params: Encodable {
            let p_session_id: UUID
        }

        guard let uuid = UUID(uuidString: sessionId) else {
            throw NSError(domain: "SupabasePracticeService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid session ID format"])
        }

        let result: SessionResult = try await client
            .rpc("get_session_result", params: Params(p_session_id: uuid))
            .execute()
            .value

        return result
    }

    private func encodedAnswer(for question: Question, answer: String?) -> FunctionAnswerValue? {
        guard let answer, !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        if question.questionType == "numeric", let value = Double(answer) {
            return .number(value)
        }
        return .string(answer)
    }
}

private struct StartPracticeSessionParams: Encodable {
    let bank_slug: String
    let override_limit: Int?
}

private struct StartPracticeSessionResponse: Decodable {
    let sessionId: String
    let totalQuestions: Int
    let bank: QuestionBank
    let questions: [QuestionPayload]

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case totalQuestions = "total_questions"
        case bank
        case questions
    }
}

private struct QuestionPayload: Decodable {
    let id: String
    let questionType: String
    let stem: String
    let options: [QuestionOption]?

    enum CodingKeys: String, CodingKey {
        case id
        case questionType = "question_type"
        case stem
        case options
    }
}

private struct SubmitAttemptPayload: Encodable {
    let session_id: String
    let question_id: String
    let answer: FunctionAnswerValue?
    let duration_ms: Int?
    let skipped: Bool?
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
