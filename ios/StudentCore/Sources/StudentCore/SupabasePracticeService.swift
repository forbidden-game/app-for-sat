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

        let response: FunctionResponse = try await invokeFunction("submit_attempt", body: payload)
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

    private func invokeFunction<Response: Decodable, Body: Encodable>(
        _ name: String,
        body: Body,
        retryOnUnauthorized: Bool = true
    ) async throws -> Response {
        do {
            let session = try await client.auth.session
            return try await client.functions.invoke(
                name,
                options: FunctionInvokeOptions(
                    headers: ["Authorization": "Bearer \(session.accessToken)"],
                    body: body
                )
            )
        } catch let error as FunctionsError {
            guard case let .httpError(code, data) = error else {
                throw error
            }

            if code == 401, retryOnUnauthorized {
                _ = try? await client.auth.refreshSession()
                return try await invokeFunction(name, body: body, retryOnUnauthorized: false)
            }

            let message = decodeFunctionError(from: data)
            let rawBody = decodeRawBody(from: data)
            let sessionDebug = currentSessionDebug()
            let description = formatFunctionError(
                code: code,
                message: message,
                rawBody: rawBody,
                sessionDebug: sessionDebug
            )
            throw NSError(
                domain: "SupabasePracticeService",
                code: code,
                userInfo: [NSLocalizedDescriptionKey: description]
            )
        }
    }

    private func decodeFunctionError(from data: Data) -> String? {
        struct FunctionErrorPayload: Decodable {
            let error: String?
        }

        guard let payload = try? JSONDecoder().decode(FunctionErrorPayload.self, from: data) else {
            return nil
        }
        return payload.error
    }

    private func decodeRawBody(from data: Data) -> String? {
        guard let raw = String(data: data, encoding: .utf8) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func formatFunctionError(
        code: Int,
        message: String?,
        rawBody: String?,
        sessionDebug: String?
    ) -> String {
        let suffix: String
#if DEBUG
        suffix = sessionDebug.map { " (\($0))" } ?? ""
#else
        suffix = ""
#endif
        switch message {
        case "missing_authorization", "invalid_authorization":
            return "Authentication expired. Please sign in again."
        default:
            if let message, !message.isEmpty {
                return "Edge function error (\(code)): \(message)\(suffix)"
            }
            if let rawBody {
                let preview = String(rawBody.prefix(200))
                return "Edge function error (\(code)): \(preview)\(suffix)"
            }
            return "Edge function error (\(code)).\(suffix)"
        }
    }

    private func currentSessionDebug() -> String? {
        guard let session = client.auth.currentSession else {
            return "session=missing"
        }
        let expired = session.isExpired ? "expired" : "valid"
        let tokenLength = session.accessToken.count
        let jwtInfo = decodeJwtInfo(from: session.accessToken) ?? "jwt=unreadable"
        return "session=\(expired),tokenLength=\(tokenLength),\(jwtInfo)"
    }

    private func decodeJwtInfo(from token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        let payloadPart = String(parts[1])
        guard let payloadData = base64URLDecode(payloadPart) else { return nil }
        guard
            let object = try? JSONSerialization.jsonObject(with: payloadData),
            let dict = object as? [String: Any]
        else {
            return nil
        }
        let iss = dict["iss"] as? String ?? "unknown"
        let aud = dict["aud"] as? String ?? "unknown"
        let role = dict["role"] as? String ?? "unknown"
        let exp = dict["exp"] as? TimeInterval ?? 0
        return "jwt=iss:\(iss),aud:\(aud),role:\(role),exp:\(Int(exp))"
    }

    private func base64URLDecode(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = 4 - (base64.count % 4)
        if padding < 4 {
            base64.append(String(repeating: "=", count: padding))
        }
        return Data(base64Encoded: base64)
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
