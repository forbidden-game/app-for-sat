import Foundation

public protocol APIClient {
    func fetchSession() async throws -> PracticeSession
}

public struct PracticeSession: Codable, Equatable {
    public let id: String
    public let questions: [Question]

    public init(id: String, questions: [Question]) {
        self.id = id
        self.questions = questions
    }
}

public final class PracticeService {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func fetchSession() async throws -> PracticeSession {
        try await client.fetchSession()
    }
}

public final class MockAPIClient: APIClient {
    public var fetchSessionCalled = false

    public init() {}

    public func fetchSession() async throws -> PracticeSession {
        fetchSessionCalled = true
        return PracticeSession(id: "S1", questions: [])
    }
}
