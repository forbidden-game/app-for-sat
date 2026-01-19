import Foundation

public enum CoachThreadRole: String, Codable {
    case user
    case assistant
    case tool
}

public struct CoachMessageContent: Codable, Equatable {
    public let text: String
    public let status: String?

    public init(text: String, status: String? = nil) {
        self.text = text
        self.status = status
    }
}

public struct CoachThreadMessage: Codable, Equatable, Identifiable {
    public let id: String
    public let role: CoachThreadRole
    public let content: CoachMessageContent
    public let linkedAttemptId: String?
    public let replyToMessageId: String?
    public let createdAt: Date

    public init(
        id: String,
        role: CoachThreadRole,
        content: CoachMessageContent,
        linkedAttemptId: String?,
        replyToMessageId: String? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.linkedAttemptId = linkedAttemptId
        self.replyToMessageId = replyToMessageId
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case content
        case linkedAttemptId = "linked_attempt_id"
        case replyToMessageId = "reply_to_message_id"
        case createdAt = "created_at"
    }
}
