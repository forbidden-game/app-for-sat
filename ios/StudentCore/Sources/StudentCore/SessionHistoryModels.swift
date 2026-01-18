import Foundation

public struct SessionHistoryItem: Codable, Equatable, Identifiable {
    public let sessionId: String
    public let createdAt: Date
    public let bankId: String?
    public let bankTitle: String?
    public let totalQuestions: Int
    public let correctCount: Int
    public let attempts: Int
    public let incorrectCount: Int
    public let durationMs: Int

    public var id: String { sessionId }

    public init(
        sessionId: String,
        createdAt: Date,
        bankId: String?,
        bankTitle: String?,
        totalQuestions: Int,
        correctCount: Int,
        attempts: Int,
        incorrectCount: Int,
        durationMs: Int
    ) {
        self.sessionId = sessionId
        self.createdAt = createdAt
        self.bankId = bankId
        self.bankTitle = bankTitle
        self.totalQuestions = totalQuestions
        self.correctCount = correctCount
        self.attempts = attempts
        self.incorrectCount = incorrectCount
        self.durationMs = durationMs
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case createdAt = "created_at"
        case bankId = "bank_id"
        case bankTitle = "bank_title"
        case totalQuestions = "total_questions"
        case correctCount = "correct_count"
        case attempts
        case incorrectCount = "incorrect_count"
        case durationMs = "duration_ms"
    }
}
