import Foundation

public enum JSONValue: Codable, Equatable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }
        if let value = try? container.decode(Double.self) {
            self = .number(value)
            return
        }
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
            return
        }
        if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
            return
        }
        throw DecodingError.typeMismatch(
            JSONValue.self,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value")
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

public struct StudentSnapshot: Codable, Equatable {
    public let studentId: String
    public let subjectScope: String
    public let weakProceduresTop: [JSONValue]
    public let weakStepsTop: [JSONValue]
    public let commonErrorModesTop: [JSONValue]
    public let recentTrend: JSONValue
    public let notes: String?
    public let updatedAt: Date

    public init(
        studentId: String,
        subjectScope: String,
        weakProceduresTop: [JSONValue],
        weakStepsTop: [JSONValue],
        commonErrorModesTop: [JSONValue],
        recentTrend: JSONValue,
        notes: String?,
        updatedAt: Date
    ) {
        self.studentId = studentId
        self.subjectScope = subjectScope
        self.weakProceduresTop = weakProceduresTop
        self.weakStepsTop = weakStepsTop
        self.commonErrorModesTop = commonErrorModesTop
        self.recentTrend = recentTrend
        self.notes = notes
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case studentId = "student_id"
        case subjectScope = "subject_scope"
        case weakProceduresTop = "weak_procedures_top"
        case weakStepsTop = "weak_steps_top"
        case commonErrorModesTop = "common_error_modes_top"
        case recentTrend = "recent_trend"
        case notes
        case updatedAt = "updated_at"
    }
}

public struct StudentReport: Codable, Equatable, Identifiable {
    public let id: String
    public let studentId: String
    public let periodKind: String
    public let periodKey: String
    public let periodStart: Date
    public let periodEnd: Date
    public let metrics: JSONValue
    public let delta: JSONValue
    public let summary: String
    public let plan: JSONValue
    public let model: String?
    public let promptVersion: String?
    public let costUsd: Double?
    public let createdAt: Date

    public init(
        id: String,
        studentId: String,
        periodKind: String,
        periodKey: String,
        periodStart: Date,
        periodEnd: Date,
        metrics: JSONValue,
        delta: JSONValue,
        summary: String,
        plan: JSONValue,
        model: String?,
        promptVersion: String?,
        costUsd: Double?,
        createdAt: Date
    ) {
        self.id = id
        self.studentId = studentId
        self.periodKind = periodKind
        self.periodKey = periodKey
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.metrics = metrics
        self.delta = delta
        self.summary = summary
        self.plan = plan
        self.model = model
        self.promptVersion = promptVersion
        self.costUsd = costUsd
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case studentId = "student_id"
        case periodKind = "period_kind"
        case periodKey = "period_key"
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case metrics
        case delta
        case summary
        case plan
        case model
        case promptVersion = "prompt_version"
        case costUsd = "cost_usd"
        case createdAt = "created_at"
    }
}
