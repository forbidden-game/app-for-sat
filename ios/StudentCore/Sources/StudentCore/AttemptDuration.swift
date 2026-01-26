import Foundation

public enum AttemptDuration {
    public static func milliseconds(from start: Date, to end: Date? = nil) -> Int {
        let endDate = end ?? Date()
        let raw = Int(endDate.timeIntervalSince(start) * 1000)
        return max(0, raw)
    }
}
