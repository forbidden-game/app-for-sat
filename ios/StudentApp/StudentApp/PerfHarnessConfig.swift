import Foundation

struct PerfHarnessConfig {
    let isEnabled: Bool
    let email: String?
    let password: String?
    let bankSlug: String?
    let durationSeconds: TimeInterval
    let paceSeconds: TimeInterval

    static var current: PerfHarnessConfig {
        let env = ProcessInfo.processInfo.environment
        let isEnabled = env["AUTOPERF"] == "1"
        let email = env["AUTOPERF_EMAIL"]
        let password = env["AUTOPERF_PASSWORD"]
        let bankSlug = env["AUTOPERF_BANK_SLUG"]
        let durationSeconds = Self.parseDouble(env["AUTOPERF_DURATION"], fallback: 180)
        let paceSeconds = Self.parseDouble(env["AUTOPERF_PACE"], fallback: 0.9)

        return PerfHarnessConfig(
            isEnabled: isEnabled,
            email: email,
            password: password,
            bankSlug: bankSlug,
            durationSeconds: durationSeconds,
            paceSeconds: paceSeconds
        )
    }

    private static func parseDouble(_ value: String?, fallback: TimeInterval) -> TimeInterval {
        guard let value, !value.isEmpty, let parsed = Double(value), parsed > 0 else {
            return fallback
        }
        return parsed
    }
}
