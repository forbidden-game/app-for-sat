import Foundation

public struct Question: Codable, Equatable {
    public let id: String
    public let questionType: String
    public let stem: String
    public let options: [QuestionOption]?
    public let answerKey: AnswerKey?

    public init(id: String, questionType: String, stem: String, options: [QuestionOption]?, answerKey: AnswerKey? = nil) {
        self.id = id
        self.questionType = questionType
        self.stem = stem
        self.options = options
        self.answerKey = answerKey
    }
}

public struct QuestionOption: Codable, Equatable {
    public let label: String
    public let content: String

    public init(label: String, content: String) {
        self.label = label
        self.content = content
    }
}

public struct AnswerKey: Codable, Equatable {
    public let correctString: String?
    public let correctNumber: Double?

    public init(correct: String) {
        correctString = correct
        correctNumber = nil
    }

    public init(correct: Double) {
        correctNumber = correct
        correctString = nil
    }

    enum CodingKeys: String, CodingKey { case correct }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? container.decode(String.self, forKey: .correct) {
            correctString = s
            correctNumber = nil
        } else if let n = try? container.decode(Double.self, forKey: .correct) {
            correctNumber = n
            correctString = nil
        } else {
            correctString = nil
            correctNumber = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let s = correctString { try container.encode(s, forKey: .correct) }
        if let n = correctNumber { try container.encode(n, forKey: .correct) }
    }
}

// MARK: - Session Result Models

public struct SessionResult: Codable, Equatable {
    public let sessionId: String
    public let totalQuestions: Int
    public let correctCount: Int
    public let questions: [QuestionResult]

    public init(sessionId: String, totalQuestions: Int, correctCount: Int, questions: [QuestionResult]) {
        self.sessionId = sessionId
        self.totalQuestions = totalQuestions
        self.correctCount = correctCount
        self.questions = questions
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case totalQuestions = "total_questions"
        case correctCount = "correct_count"
        case questions
    }
}

public struct QuestionResult: Codable, Equatable, Identifiable {
    public let questionId: String
    public let position: Int
    public let isCorrect: Bool
    public let userAnswer: AnswerValue?
    public let correctAnswer: AnswerValue
    public let stem: String
    public let options: [QuestionOption]?
    public let explanation: String

    public var id: String { questionId }

    public init(
        questionId: String,
        position: Int,
        isCorrect: Bool,
        userAnswer: AnswerValue?,
        correctAnswer: AnswerValue,
        stem: String,
        options: [QuestionOption]?,
        explanation: String
    ) {
        self.questionId = questionId
        self.position = position
        self.isCorrect = isCorrect
        self.userAnswer = userAnswer
        self.correctAnswer = correctAnswer
        self.stem = stem
        self.options = options
        self.explanation = explanation
    }

    enum CodingKeys: String, CodingKey {
        case questionId = "question_id"
        case position
        case isCorrect = "is_correct"
        case userAnswer = "user_answer"
        case correctAnswer = "correct_answer"
        case stem
        case options
        case explanation
    }
}

public enum AnswerValue: Codable, Equatable {
    case string(String)
    case number(Double)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let n = try? container.decode(Double.self) {
            self = .number(n)
        } else {
            throw DecodingError.typeMismatch(
                AnswerValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or Number")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .number(let n): try container.encode(n)
        }
    }

    public var displayString: String {
        switch self {
        case .string(let s): return s
        case .number(let n):
            if n.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f", n)
            }
            return String(n)
        }
    }
}
