import XCTest
@testable import StudentCore

final class AttemptDurationTests: XCTestCase {
    func testMillisecondsReturnsZeroForNegativeInterval() {
        let start = Date(timeIntervalSince1970: 10)
        let end = Date(timeIntervalSince1970: 9)
        XCTAssertEqual(AttemptDuration.milliseconds(from: start, to: end), 0)
    }

    func testMillisecondsConvertsSecondsToMilliseconds() {
        let start = Date(timeIntervalSince1970: 10)
        let end = Date(timeIntervalSince1970: 12)
        XCTAssertEqual(AttemptDuration.milliseconds(from: start, to: end), 2000)
    }
}
