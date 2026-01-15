import Foundation

enum AppConfig {
    static let autoAdvanceDelayMsDefault = 220

    static var autoAdvanceDelayMs: Int {
        let value = UserDefaults.standard.integer(forKey: "autoAdvanceDelayMs")
        return value > 0 ? value : autoAdvanceDelayMsDefault
    }
}
