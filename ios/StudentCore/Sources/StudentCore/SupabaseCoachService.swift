import Foundation
import Supabase

public final class SupabaseCoachService {
    private let client: SupabaseClient

    private var channel: RealtimeChannelV2?
    private var subscriptions: [RealtimeSubscription] = []

    public init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    public func fetchThreadMessages(studentId: String, limit: Int = 50) async throws -> [CoachThreadMessage] {
        struct Row: Decodable {
            let id: UUID
            let role: CoachThreadRole
            let content: CoachMessageContent
            let linked_attempt_id: UUID?
            let created_at: Date
        }

        guard let studentUUID = UUID(uuidString: studentId) else {
            throw NSError(domain: "SupabaseCoachService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid student ID format"])
        }

        let rows: [Row] = try await client
            .from("coach_thread_messages")
            .select("id, role, content, linked_attempt_id, created_at")
            .eq("student_id", value: studentUUID)
            .order("created_at", ascending: true)
            .limit(limit)
            .execute()
            .value

        return rows.map { row in
            CoachThreadMessage(
                id: row.id.uuidString,
                role: row.role,
                content: row.content,
                linkedAttemptId: row.linked_attempt_id?.uuidString,
                createdAt: row.created_at
            )
        }
    }

    public func sendMessage(text: String, linkedAttemptId: String? = nil) async throws -> String {
        struct Payload: Encodable {
            let text: String
            let linked_attempt_id: String?
        }

        struct FunctionResponse: Decodable {
            let ok: Bool
            let userMessageId: String
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "SupabaseCoachService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty message"])
        }

        let session = try await client.auth.session

        let response: FunctionResponse = try await client.functions.invoke(
            "coach_chat",
            options: FunctionInvokeOptions(
                headers: [
                    "Authorization": "Bearer \(session.accessToken)",
                    "apikey": SupabaseConfig.anonKey,
                ],
                body: Payload(text: trimmed, linked_attempt_id: linkedAttemptId)
            )
        )

        if response.ok != true {
            throw NSError(domain: "SupabaseCoachService", code: -1, userInfo: [NSLocalizedDescriptionKey: "coach_chat failed"])
        }

        return response.userMessageId
    }

    private static func parseISODate(_ value: String) -> Date {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: value) ?? Date()
    }

    public func startRealtime(
        studentId: String,
        onUpsert: @escaping @MainActor (CoachThreadMessage) -> Void
    ) async throws {
        await stopRealtime()

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
