import XCTest
@testable import StudentCore

final class JwtUtilsTests: XCTestCase {
    func testExpirationParsesExp() {
        let exp: TimeInterval = 1_768_328_752
        let token = makeToken(payload: ["exp": exp])
        XCTAssertEqual(JwtUtils.expiration(from: token), exp)
    }

    func testDebugSummaryIncludesFields() {
        let token = makeToken(payload: [
            "iss": "https://example.supabase.co/auth/v1",
            "aud": "authenticated",
            "role": "authenticated",
            "exp": 1_768_328_752,
        ])

        let summary = JwtUtils.debugSummary(from: token)
        XCTAssertNotNil(summary)
        XCTAssertTrue(summary?.contains("iss:https://example.supabase.co/auth/v1") == true)
        XCTAssertTrue(summary?.contains("aud:authenticated") == true)
        XCTAssertTrue(summary?.contains("role:authenticated") == true)
        XCTAssertTrue(summary?.contains("exp:1768328752") == true)
    }

    private func makeToken(payload: [String: Any]) -> String {
        let header = ["alg": "HS256", "typ": "JWT"]
        let headerPart = base64URLString(for: header)
        let payloadPart = base64URLString(for: payload)
        return "\(headerPart).\(payloadPart).signature"
    }

    private func base64URLString(for object: [String: Any]) -> String {
        let data = try! JSONSerialization.data(withJSONObject: object, options: [])
        return data
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
