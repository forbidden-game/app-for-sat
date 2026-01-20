import Foundation

public struct FriendThreadSummary: Codable, Identifiable, Hashable {
    public let threadId: String
    public let friendId: String
    public let username: String
    public let avatarUrl: String?
    public let rating: Int?
    public let lastMessage: String?
    public let lastSeen: Date?

    public var id: String { friendId }

    public init(
        threadId: String,
        friendId: String,
        username: String,
        avatarUrl: String?,
        rating: Int?,
        lastMessage: String?,
        lastSeen: Date?
    ) {
        self.threadId = threadId
        self.friendId = friendId
        self.username = username
        self.avatarUrl = avatarUrl
        self.rating = rating
        self.lastMessage = lastMessage
        self.lastSeen = lastSeen
    }
}

public struct FriendMessage: Codable, Identifiable, Hashable {
    public let id: String
    public let threadId: String
    public let senderId: String
    public let content: String
    public let createdAt: Date

    public init(id: String, threadId: String, senderId: String, content: String, createdAt: Date) {
        self.id = id
        self.threadId = threadId
        self.senderId = senderId
        self.content = content
        self.createdAt = createdAt
    }
}
