import Foundation

public struct StudyBehavior: Decodable {
    public struct State: Decodable {
        public let label: String
        public let confidence: Double?
    }

    public struct Metrics: Decodable {
        public let minutes: Double
        public let minutesDelta: Double
        public let accuracy: Double?
        public let accuracyDelta: Double?
        public let activeDays: Int
        public let activeDaysDelta: Int
        public let attempts: Int

        enum CodingKeys: String, CodingKey {
            case minutes
            case minutesDelta = "minutes_delta"
            case accuracy
            case accuracyDelta = "accuracy_delta"
            case activeDays = "active_days"
            case activeDaysDelta = "active_days_delta"
            case attempts
        }
    }

    public struct DailyPoint: Decodable, Identifiable {
        public let date: String
        public let minutes: Double
        public let attempts: Int
        public let accuracy: Double?

        public var id: String { date }
    }

    public struct WeeklyPoint: Decodable, Identifiable {
        public let weekStart: String
        public let minutes: Double
        public let attempts: Int
        public let accuracy: Double?
        public let activeDays: Int

        public var id: String { weekStart }

        enum CodingKeys: String, CodingKey {
            case weekStart = "week_start"
            case minutes
            case attempts
            case accuracy
            case activeDays = "active_days"
        }
    }

    public let studentId: String
    public let windowDays: Int
    public let state: State
    public let drivers: [String]
    public let metrics: Metrics
    public let daily: [DailyPoint]
    public let weekly: [WeeklyPoint]

    enum CodingKeys: String, CodingKey {
        case studentId = "student_id"
        case windowDays = "window_days"
        case state
        case drivers
        case metrics
        case daily
        case weekly
    }
}
