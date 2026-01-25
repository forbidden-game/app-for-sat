import Foundation

public enum AttemptDuration {
    public static func milliseconds(from start: Date, to end: Date = .now) -> Int {
        let raw = Int(end.timeIntervalSince(start) * 1000)
        return max(0, raw)
    }
}
