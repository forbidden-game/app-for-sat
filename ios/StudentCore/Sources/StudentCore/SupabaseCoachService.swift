import Foundation
import Supabase

public final class SupabaseCoachService {
    private let client: SupabaseClient
    private let tokenProvider: SupabaseAuthTokenProvider

    private var channel: RealtimeChannelV2?
    private var subscriptions: [RealtimeSubscription] = []

    public init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
        self.tokenProvider = SupabaseAuthTokenProvider(client: client)
    }

    public func fetchThreadMessages(studentId: String, limit: Int = 50) async throws -> [CoachThreadMessage] {
        struct Row: Decodable {
            let id: UUID
            let role: CoachThreadRole
            let content: CoachMessageContent
            let linked_attempt_id: UUID?
            let reply_to_message_id: UUID?
            let created_at: Date
        }

        guard let studentUUID = UUID(uuidString: studentId) else {
            throw NSError(domain: "SupabaseCoachService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid student ID format"])
        }

        let rows: [Row] = try await client
            .from("coach_thread_messages")
            .select("id, role, content, linked_attempt_id, reply_to_message_id, created_at")
            .eq("student_id", value: studentUUID)
            // Fetch latest N, then reverse to chronological for chat UI.
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return rows.reversed().map { row in
            CoachThreadMessage(
                id: row.id.uuidString,
                role: row.role,
                content: row.content,
                linkedAttemptId: row.linked_attempt_id?.uuidString,
                replyToMessageId: row.reply_to_message_id?.uuidString,
                createdAt: row.created_at
            )
        }
    }

    public func fetchStudentSnapshot(studentId: String) async throws -> StudentSnapshot? {
        struct SnapshotRow: Decodable {
            let student_id: UUID
            let subject_scope: String
            let weak_procedures_top: [JSONValue]
            let weak_steps_top: [JSONValue]
            let common_error_modes_top: [JSONValue]
            let recent_trend: JSONValue
            let notes: String?
            let updated_at: Date
        }

        guard let studentUUID = UUID(uuidString: studentId) else {
            throw NSError(domain: "SupabaseCoachService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid student ID format"])
        }

        let rows: [SnapshotRow] = try await client
            .from("student_snapshots")
            .select("student_id, subject_scope, weak_procedures_top, weak_steps_top, common_error_modes_top, recent_trend, notes, updated_at")
            .eq("student_id", value: studentUUID)
            .limit(1)
            .execute()
            .value

        guard let row = rows.first else { return nil }

        return StudentSnapshot(
            studentId: row.student_id.uuidString,
            subjectScope: row.subject_scope,
            weakProceduresTop: row.weak_procedures_top,
            weakStepsTop: row.weak_steps_top,
            commonErrorModesTop: row.common_error_modes_top,
            recentTrend: row.recent_trend,
            notes: row.notes,
            updatedAt: row.updated_at
        )
    }

    public func fetchStudentReports(
        studentId: String,
        periodKind: String,
        limit: Int = 4
    ) async throws -> [StudentReport] {
        struct ReportRow: Decodable {
            let id: UUID
            let student_id: UUID
            let period_kind: String
            let period_key: String
            let period_start: Date
            let period_end: Date
            let metrics: JSONValue
            let delta: JSONValue
            let summary: String
            let plan: JSONValue
            let model: String?
            let prompt_version: String?
            let cost_usd: Double?
            let created_at: Date
        }

        let trimmedKind = periodKind.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKind.isEmpty else {
            throw NSError(domain: "SupabaseCoachService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid period kind"])
        }

        guard let studentUUID = UUID(uuidString: studentId) else {
            throw NSError(domain: "SupabaseCoachService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid student ID format"])
        }

        guard limit > 0 else { return [] }

        let rows: [ReportRow] = try await client
            .from("student_reports")
            .select("id, student_id, period_kind, period_key, period_start, period_end, metrics, delta, summary, plan, model, prompt_version, cost_usd, created_at")
            .eq("student_id", value: studentUUID)
            .eq("period_kind", value: trimmedKind)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return rows.map { row in
            StudentReport(
                id: row.id.uuidString,
                studentId: row.student_id.uuidString,
                periodKind: row.period_kind,
                periodKey: row.period_key,
                periodStart: row.period_start,
                periodEnd: row.period_end,
                metrics: row.metrics,
                delta: row.delta,
                summary: row.summary,
                plan: row.plan,
                model: row.model,
                promptVersion: row.prompt_version,
                costUsd: row.cost_usd,
                createdAt: row.created_at
            )
        }
    }

    public func sendMessage(
        text: String,
        linkedAttemptId: String? = nil,
        replyToMessageId: String? = nil
    ) async throws -> String {
        struct Payload: Encodable {
            let text: String
            let linked_attempt_id: String?
            let reply_to_message_id: String?
        }

        struct FunctionResponse: Decodable {
            let ok: Bool
            let userMessageId: String
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "SupabaseCoachService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty message"])
        }

        let accessToken = try await tokenProvider.accessToken()

        let response: FunctionResponse = try await client.functions.invoke(
            "coach_chat",
            options: FunctionInvokeOptions(
                headers: [
                    "Authorization": "Bearer \(accessToken)",
                    "apikey": SupabaseConfig.anonKey,
                ],
                body: Payload(text: trimmed, linked_attempt_id: linkedAttemptId, reply_to_message_id: replyToMessageId)
            )
        )

        if response.ok != true {
            throw NSError(domain: "SupabaseCoachService", code: -1, userInfo: [NSLocalizedDescriptionKey: "coach_chat failed"])
        }

        return response.userMessageId
    }

    private static let isoFormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parseISODate(_ value: String) -> Date {
        if let date = isoFormatterWithFractional.date(from: value) {
            return date
        }
        if let date = isoFormatter.date(from: value) {
            return date
        }
        return Date()
    }

    public func startRealtime(
        studentId: String,
        onUpsert: @escaping @MainActor (CoachThreadMessage) -> Void
    ) async throws {
        await stopRealtime()

        let accessToken = try await tokenProvider.accessToken()
        await client.realtimeV2.setAuth(accessToken)
        await client.realtimeV2.connect()

        let decoder = JSONDecoder()
        let topic = "coach_thread_messages:student=\(studentId)"

        let newChannel = client.channel(topic)

        let filter = "student_id=eq.\(studentId)"

        subscriptions.append(
            newChannel.onPostgresChange(InsertAction.self, schema: "public", table: "coach_thread_messages", filter: filter) { action in
                do {
                    struct Row: Decodable {
                        let id: UUID
                        let role: CoachThreadRole
                        let content: CoachMessageContent
                        let linked_attempt_id: UUID?
                        let reply_to_message_id: UUID?
                        let created_at: String
                    }
                    let row = try action.decodeRecord(as: Row.self, decoder: decoder)
                    Task { @MainActor in
                        onUpsert(
                            CoachThreadMessage(
                                id: row.id.uuidString,
                                role: row.role,
                                content: row.content,
                                linkedAttemptId: row.linked_attempt_id?.uuidString,
                                replyToMessageId: row.reply_to_message_id?.uuidString,
                                createdAt: SupabaseCoachService.parseISODate(row.created_at)
                            )
                        )
                    }
                } catch {
                    return
                }
            }
        )

        subscriptions.append(
            newChannel.onPostgresChange(UpdateAction.self, schema: "public", table: "coach_thread_messages", filter: filter) { action in
                do {
                    struct Row: Decodable {
                        let id: UUID
                        let role: CoachThreadRole
                        let content: CoachMessageContent
                        let linked_attempt_id: UUID?
                        let reply_to_message_id: UUID?
                        let created_at: String
                    }
                    let row = try action.decodeRecord(as: Row.self, decoder: decoder)
                    Task { @MainActor in
                        onUpsert(
                            CoachThreadMessage(
                                id: row.id.uuidString,
                                role: row.role,
                                content: row.content,
                                linkedAttemptId: row.linked_attempt_id?.uuidString,
                                replyToMessageId: row.reply_to_message_id?.uuidString,
                                createdAt: SupabaseCoachService.parseISODate(row.created_at)
                            )
                        )
                    }
                } catch {
                    return
                }
            }
        )

        try await newChannel.subscribeWithError()
        channel = newChannel
    }

    public func stopRealtime() async {
        for sub in subscriptions {
            sub.cancel()
        }
        subscriptions.removeAll()

        if let channel {
            await channel.unsubscribe()
            self.channel = nil
        }
    }
}
