import Foundation
import Supabase

public struct PracticeSessionRow: Decodable {
    public let id: UUID
}

public struct RecommendedPracticeSession {
    public let session: PracticeSession
    public let bank: QuestionBank

    public init(session: PracticeSession, bank: QuestionBank) {
        self.session = session
        self.bank = bank
    }
}

public final class SupabasePracticeService {
    private let client: SupabaseClient
    private let tokenProvider: SupabaseAuthTokenProvider

    public init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
        self.tokenProvider = SupabaseAuthTokenProvider(client: client)
    }

    private static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
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
                answerKey: nil,
                subject: payload.subject
            )
        }

        return PracticeSession(id: response.sessionId, questions: questions)
    }

    public func startRecommendedPracticeSession() async throws -> RecommendedPracticeSession {
        let response: StartPracticeSessionResponse = try await client
            .rpc("start_recommended_practice_session", params: EmptyParams())
            .execute()
            .value

        let questions = response.questions.map { payload in
            Question(
                id: payload.id,
                questionType: payload.questionType,
                stem: payload.stem,
                options: payload.options,
                answerKey: nil,
                subject: payload.subject
            )
        }

        let session = PracticeSession(id: response.sessionId, questions: questions)
        return RecommendedPracticeSession(session: session, bank: response.bank)
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
        clientSubmissionId: String,
        durationMs: Int? = nil,
        skipped: Bool? = nil
    ) async throws -> SubmitAttemptResult {
        let payload = SubmitAttemptPayload(
            session_id: sessionId,
            question_id: question.id,
            client_submission_id: clientSubmissionId,
            answer: encodedAnswer(for: question, answer: answer),
            duration_ms: durationMs,
            skipped: skipped
        )

        struct FunctionResponse: Decodable {
            let isCorrect: Bool
            let attemptId: String
        }

        let response: FunctionResponse = try await invokeFunction("submit_attempt", body: payload)
        return SubmitAttemptResult(isCorrect: response.isCorrect, attemptId: response.attemptId)
    }

    public func setAttemptStepSelection(
        attemptId: String,
        selectedStepIndex: Int?,
        isUnknown: Bool
    ) async throws {
        let payload = SetAttemptStepPayload(
            attempt_id: attemptId,
            student_selected_step_index: selectedStepIndex,
            student_selected_step_is_unknown: isUnknown
        )

        struct FunctionResponse: Decodable {
            let ok: Bool
        }

        let response: FunctionResponse = try await invokeFunction("set_attempt_step", body: payload)
        if response.ok != true {
            throw NSError(
                domain: "SupabasePracticeService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to set attempt step selection"]
            )
        }
    }

    public func fetchAttemptInsight(attemptId: String) async throws -> AttemptInsight? {
        guard let uuid = UUID(uuidString: attemptId) else {
            throw NSError(domain: "SupabasePracticeService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid attempt ID format"])
        }

        struct InsightRow: Decodable {
            let attempt_id: UUID
            let explanation_short: String
            let followups: [AttemptFollowup]
        }

        let rows: [InsightRow] = try await client
            .from("attempt_insights")
            .select("attempt_id, explanation_short, followups")
            .eq("attempt_id", value: uuid)
            .limit(1)
            .execute()
            .value

        guard let row = rows.first else { return nil }
        return AttemptInsight(
            attemptId: row.attempt_id.uuidString,
            explanationShort: row.explanation_short,
            followups: row.followups
        )
    }

    public func requestEnglishGrammarAnalysis(questionId: String) async throws -> EnglishGrammarAnalysisRecord {
        guard let uuid = UUID(uuidString: questionId) else {
            throw NSError(domain: "SupabasePracticeService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid question ID format"])
        }

        struct RequestParams: Encodable {
            let p_question_id: UUID
        }

        struct RequestRow: Decodable {
            let question_id: UUID
            let status: String
            let prompt_version: String
            let updated_at: String
        }

        let rows: [RequestRow] = try await client
            .rpc(
                "request_english_grammar_analysis",
                params: RequestParams(
                    p_question_id: uuid
                )
            )
            .execute()
            .value

        guard let row = rows.first else {
            throw NSError(domain: "SupabasePracticeService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty grammar analysis response"])
        }

        let status = EnglishGrammarAnalysisStatus(rawValue: row.status) ?? .queued
        return EnglishGrammarAnalysisRecord(
            status: status,
            analysis: nil,
            error: nil,
            promptVersion: row.prompt_version,
            updatedAt: row.updated_at
        )
    }

    public func fetchEnglishGrammarAnalysis(questionId: String) async throws -> EnglishGrammarAnalysisRecord? {
        guard let uuid = UUID(uuidString: questionId) else {
            throw NSError(domain: "SupabasePracticeService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid question ID format"])
        }

        struct AnalysisRow: Decodable {
            let status: String
            let result: EnglishGrammarAnalysis?
            let error: String?
            let prompt_version: String
            let updated_at: String
        }

        let rows: [AnalysisRow] = try await client
            .from("english_grammar_analyses")
            .select("status, result, error, prompt_version, updated_at")
            .eq("question_id", value: uuid)
            .order("updated_at", ascending: false)
            .limit(1)
            .execute()
            .value

        guard let row = rows.first else { return nil }
        let status = EnglishGrammarAnalysisStatus(rawValue: row.status) ?? .queued
        return EnglishGrammarAnalysisRecord(
            status: status,
            analysis: row.result,
            error: row.error,
            promptVersion: row.prompt_version,
            updatedAt: row.updated_at
        )
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

    public func fetchSessionHistory(
        start: Date? = nil,
        end: Date? = nil,
        bankId: String? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [SessionHistoryItem] {
        struct Params: Encodable {
            let p_start: String?
            let p_end: String?
            let p_bank_id: String?
            let p_limit: Int
            let p_offset: Int
        }

        let params = Params(
            p_start: start.map { Self.iso8601String(from: $0) },
            p_end: end.map { Self.iso8601String(from: $0) },
            p_bank_id: bankId,
            p_limit: limit,
            p_offset: offset
        )

        let items: [SessionHistoryItem] = try await client
            .rpc("get_session_history", params: params)
            .execute()
            .value

        return items
    }

    public func fetchStudyBehavior(windowDays: Int = 7, historyWeeks: Int = 8) async throws -> StudyBehavior {
        let params = StudyBehaviorParams(
            target_student_id: nil,
            window_days: windowDays,
            history_weeks: historyWeeks
        )

        let behavior: StudyBehavior = try await client
            .rpc("get_study_behavior", params: params)
            .execute()
            .value

        return behavior
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
        accessToken: String? = nil,
        retryOnUnauthorized: Bool = true
    ) async throws -> Response {
        do {
            let token: String
            if let accessToken {
                token = accessToken
            } else {
                token = try await tokenProvider.accessToken()
            }
#if DEBUG
            let session = client.auth.currentSession
            let sessionState = session == nil ? "missing" : "present"
            let exp = session.map { Int($0.expiresAt) }
            let jwtSummary = session.flatMap { JwtUtils.debugSummary(from: $0.accessToken) } ?? "jwt=missing"
            print("[SupabasePracticeService] invoke \(name) session=\(sessionState) exp=\(exp.map(String.init) ?? "n/a") \(jwtSummary)")
#endif
            return try await client.functions.invoke(
                name,
                options: FunctionInvokeOptions(
                    headers: [
                        "Authorization": "Bearer \(token)",
                        "apikey": SupabaseConfig.anonKey,
                    ],
                    body: body
                )
            )
        } catch let error as AuthError {
            if error == .sessionMissing {
                try? await client.auth.signOut()
                throw NSError(
                    domain: "SupabasePracticeService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Authentication expired. Please sign in again."]
                )
            }
            throw error
        } catch let error as FunctionsError {
            guard case let .httpError(code, data) = error else {
                throw error
            }

            if code == 401, retryOnUnauthorized {
#if DEBUG
                let message = decodeFunctionError(from: data) ?? "unknown"
                print("[SupabasePracticeService] 401 retrying after refresh: \(message)")
#endif
                do {
                    let refreshedToken = try await tokenProvider.refreshAccessToken()
                    return try await invokeFunction(
                        name,
                        body: body,
                        accessToken: refreshedToken,
                        retryOnUnauthorized: false
                    )
                } catch {
                    try? await client.auth.signOut()
                    throw NSError(
                        domain: "SupabasePracticeService",
                        code: code,
                        userInfo: [NSLocalizedDescriptionKey: "Authentication expired. Please sign in again."]
                    )
                }
            }

            let message = decodeFunctionError(from: data)
            let rawBody = decodeRawBody(from: data)
            let sessionDebug = currentSessionDebug()
            if code == 401, isInvalidJwt(message: message, rawBody: rawBody) {
                try? await client.auth.signOut()
                throw NSError(
                    domain: "SupabasePracticeService",
                    code: code,
                    userInfo: [NSLocalizedDescriptionKey: "Authentication expired. Please sign in again."]
                )
            }
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

        struct FunctionMessagePayload: Decodable {
            let message: String?
        }

        if let payload = try? JSONDecoder().decode(FunctionErrorPayload.self, from: data),
           let error = payload.error,
           !error.isEmpty {
            return error
        }

        if let payload = try? JSONDecoder().decode(FunctionMessagePayload.self, from: data),
           let message = payload.message,
           !message.isEmpty {
            return message
        }

        if let object = try? JSONSerialization.jsonObject(with: data),
           let dict = object as? [String: Any] {
            if let error = dict["error"] as? String, !error.isEmpty {
                return error
            }
            if let message = dict["message"] as? String, !message.isEmpty {
                return message
            }
        }

        return nil
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
        if isInvalidJwt(message: message, rawBody: rawBody) {
            return "Authentication expired. Please sign in again."
        }

        if let message, !message.isEmpty {
            return "Edge function error (\(code)): \(message)\(suffix)"
        }
        if let rawBody {
            let preview = String(rawBody.prefix(200))
            return "Edge function error (\(code)): \(preview)\(suffix)"
        }
        return "Edge function error (\(code)).\(suffix)"
    }

    private func currentSessionDebug() -> String? {
        guard let session = client.auth.currentSession else {
            return "session=missing"
        }
        let expired = session.isExpired ? "expired" : "valid"
        let tokenLength = session.accessToken.count
        let jwtInfo = JwtUtils.debugSummary(from: session.accessToken) ?? "jwt=unreadable"
        let now = Int(Date().timeIntervalSince1970)
        let exp = JwtUtils.expiration(from: session.accessToken).map { Int($0) }
        let expDelta = exp.map { $0 - now }
        let timing = expDelta.map { "now=\(now),expIn=\($0)s" } ?? "now=\(now)"
        return "session=\(expired),tokenLength=\(tokenLength),\(jwtInfo),\(timing)"
    }

    private func isInvalidJwt(message: String?, rawBody: String?) -> Bool {
        let normalizedMessage = message?.lowercased()
        let normalizedRaw = rawBody?.lowercased()

        if normalizedMessage == "missing_authorization"
            || normalizedMessage == "invalid_authorization"
            || normalizedMessage?.contains("invalid jwt") == true
            || normalizedMessage?.contains("jwt expired") == true {
            return true
        }

        if normalizedRaw?.contains("invalid jwt") == true {
            return true
        }

        if let rawBody,
           let data = rawBody.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data),
           let dict = object as? [String: Any],
           let message = dict["message"] as? String,
           message.lowercased().contains("invalid jwt") == true {
            return true
        }

        return false
    }
}

private struct EmptyParams: Encodable {}

private struct StartPracticeSessionParams: Encodable {
    let bank_slug: String
    let override_limit: Int?
}

private struct StudyBehaviorParams: Encodable {
    let target_student_id: String?
    let window_days: Int?
    let history_weeks: Int?
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
    let subject: String?
    let questionType: String
    let stem: String
    let options: [QuestionOption]?

    enum CodingKeys: String, CodingKey {
        case id
        case subject
        case questionType = "question_type"
        case stem
        case options
    }
}

private struct SubmitAttemptPayload: Encodable {
    let session_id: String
    let question_id: String
    let client_submission_id: String
    let answer: FunctionAnswerValue?
    let duration_ms: Int?
    let skipped: Bool?
}

private struct SetAttemptStepPayload: Encodable {
    let attempt_id: String
    let student_selected_step_index: Int?
    let student_selected_step_is_unknown: Bool
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
