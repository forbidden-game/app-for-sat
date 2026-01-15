import Foundation

enum AppConfig {
    static let autoAdvanceDelayMsDefault = 220
    static let swiftMathEnabledDefault = true

    static var autoAdvanceDelayMs: Int {
        let value = UserDefaults.standard.integer(forKey: "autoAdvanceDelayMs")
        return value > 0 ? value : autoAdvanceDelayMsDefault
    }

    static var swiftMathEnabled: Bool {
        if let value = UserDefaults.standard.object(forKey: "swiftMathEnabled") as? Bool {
            return value
        }
        return swiftMathEnabledDefault
    }
}
