import Foundation

enum JwtUtils {
    static func payload(from token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        let payloadPart = String(parts[1])
        guard let payloadData = base64URLDecode(payloadPart) else { return nil }
        guard
            let object = try? JSONSerialization.jsonObject(with: payloadData),
            let dict = object as? [String: Any]
        else {
            return nil
        }
        return dict
    }

    static func expiration(from token: String) -> TimeInterval? {
        guard let dict = payload(from: token) else { return nil }
        if let exp = dict["exp"] as? TimeInterval {
            return exp
        }
        if let exp = dict["exp"] as? NSNumber {
            return exp.doubleValue
        }
        return nil
    }

    static func debugSummary(from token: String) -> String? {
        guard let dict = payload(from: token) else { return nil }
        let iss = dict["iss"] as? String ?? "unknown"
        let aud = dict["aud"] as? String ?? "unknown"
        let role = dict["role"] as? String ?? "unknown"
        let sub = dict["sub"] as? String ?? "unknown"
        let exp = (dict["exp"] as? NSNumber)?.doubleValue ?? 0
        return "jwt=iss:\(iss),aud:\(aud),role:\(role),sub:\(sub),exp:\(Int(exp))"
    }

    static func issuer(from token: String) -> String? {
        guard let dict = payload(from: token) else { return nil }
        return dict["iss"] as? String
    }

    private static func base64URLDecode(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = 4 - (base64.count % 4)
        if padding < 4 {
            base64.append(String(repeating: "=", count: padding))
        }
        return Data(base64Encoded: base64)
    }
}
