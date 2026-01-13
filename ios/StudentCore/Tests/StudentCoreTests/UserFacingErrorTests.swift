import XCTest
@testable import StudentCore

final class UserFacingErrorTests: XCTestCase {
    func testTLSMapsToHelpfulMessage() {
        let msg = UserFacingError.message(URLError(.secureConnectionFailed))
        XCTAssertTrue(msg.contains("TLS"))
    }

    func testOfflineMapsToHelpfulMessage() {
        let msg = UserFacingError.message(URLError(.notConnectedToInternet))
        XCTAssertTrue(msg.contains("网络未连接"))
    }
}
