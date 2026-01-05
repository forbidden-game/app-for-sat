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
