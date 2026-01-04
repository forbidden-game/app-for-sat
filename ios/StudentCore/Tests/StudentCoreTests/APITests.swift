import XCTest
@testable import StudentCore

final class APITests: XCTestCase {
    func testFetchSessionUsesClient() async throws {
        let client = MockAPIClient()
        let service = PracticeService(client: client)
        _ = try await service.fetchSession()
        XCTAssertEqual(client.fetchSessionCalled, true)
    }
}
