import Foundation
import Supabase

public final class SupabaseFriendsService {
    private let client: SupabaseClient

    public init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    public func fetchFriendThreads() async throws -> [FriendThreadSummary] {
        struct Row: Decodable {
            let thread_id: UUID
            let friend_id: UUID
            let username: String
            let avatar_url: String?
            let rating: Int?
            let last_message: String?
            let last_seen: Date?
        }

        let rows: [Row] = try await client
            .from("friend_threads")
            .select("thread_id, friend_id, username, avatar_url, rating, last_message, last_seen")
            .order("last_seen", ascending: false, nullsFirst: false)
            .execute()
            .value

        return rows.map { row in
            FriendThreadSummary(
                threadId: row.thread_id.uuidString,
                friendId: row.friend_id.uuidString,
                username: row.username,
                avatarUrl: row.avatar_url,
                rating: row.rating,
                lastMessage: row.last_message,
                lastSeen: row.last_seen
            )
        }
    }

    public func fetchFriendMessages(threadId: String, limit: Int = 50) async throws -> [FriendMessage] {
        struct Row: Decodable {
            let id: UUID
            let thread_id: UUID
            let sender_id: UUID
            let content: String
            let created_at: Date
        }

        guard let threadUUID = UUID(uuidString: threadId) else {
            throw NSError(domain: "SupabaseFriendsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid thread ID format"])
        }

        let rows: [Row] = try await client
            .from("friend_messages")
            .select("id, thread_id, sender_id, content, created_at")
            .eq("thread_id", value: threadUUID)
            .order("created_at", ascending: true)
            .limit(limit)
            .execute()
            .value

        return rows.map { row in
            FriendMessage(
                id: row.id.uuidString,
                threadId: row.thread_id.uuidString,
                senderId: row.sender_id.uuidString,
                content: row.content,
                createdAt: row.created_at
            )
        }
    }

    public func sendFriendMessage(threadId: String, text: String) async throws -> FriendMessage {
        struct InsertPayload: Encodable {
            let thread_id: UUID
            let content: String
        }

        struct Row: Decodable {
            let id: UUID
            let thread_id: UUID
            let sender_id: UUID
            let content: String
            let created_at: Date
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "SupabaseFriendsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty message"])
        }

        guard let threadUUID = UUID(uuidString: threadId) else {
            throw NSError(domain: "SupabaseFriendsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid thread ID format"])
        }

        let payload = InsertPayload(thread_id: threadUUID, content: trimmed)

        let response: Row = try await client
            .from("friend_messages")
            .insert(payload)
            .select("id, thread_id, sender_id, content, created_at")
            .single()
            .execute()
            .value

        return FriendMessage(
            id: response.id.uuidString,
            threadId: response.thread_id.uuidString,
            senderId: response.sender_id.uuidString,
            content: response.content,
            createdAt: response.created_at
        )
    }
}
