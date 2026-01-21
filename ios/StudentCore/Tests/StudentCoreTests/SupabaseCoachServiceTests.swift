import Foundation
import XCTest
@testable import StudentCore

final class SupabaseCoachServiceTests: XCTestCase {
    func testParseISODateWithFractionalSeconds() {
        let base = makeUTCDate(year: 2026, month: 1, day: 21, hour: 15, minute: 0, second: 0)
        let expected = base.addingTimeInterval(0.123)
        let parsed = SupabaseCoachService.parseISODate("2026-01-21T15:00:00.123Z")
        XCTAssertEqual(parsed.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 0.0001)
    }

    func testParseISODateWithoutFractionalSeconds() {
        let expected = makeUTCDate(year: 2026, month: 1, day: 21, hour: 15, minute: 0, second: 0)
        let parsed = SupabaseCoachService.parseISODate("2026-01-21T15:00:00+00:00")
        XCTAssertEqual(parsed, expected)
    }

    func testParseISODateFallsBackToNow() {
        let now = Date()
        let parsed = SupabaseCoachService.parseISODate("not-a-date")
        XCTAssertLessThan(abs(parsed.timeIntervalSince(now)), 2)
    }

    private func makeUTCDate(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return components.date!
    }
}
