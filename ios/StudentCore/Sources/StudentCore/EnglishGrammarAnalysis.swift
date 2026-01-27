import Foundation

public enum EnglishGrammarAnalysisStatus: String, Codable, Equatable {
    case queued
    case running
    case done
    case error
}

public struct EnglishGrammarAnalysisRecord: Codable, Equatable {
    public let status: EnglishGrammarAnalysisStatus
    public let analysis: EnglishGrammarAnalysis?
    public let error: String?
    public let promptVersion: String
    public let updatedAt: String

    public init(
        status: EnglishGrammarAnalysisStatus,
        analysis: EnglishGrammarAnalysis?,
        error: String?,
        promptVersion: String,
        updatedAt: String
    ) {
        self.status = status
        self.analysis = analysis
        self.error = error
        self.promptVersion = promptVersion
        self.updatedAt = updatedAt
    }
}

public struct EnglishGrammarSentencePair: Codable, Equatable {
    public let zh: String
    public let en: String

    public init(zh: String, en: String) {
        self.zh = zh
        self.en = en
    }
}

public struct EnglishGrammarAnalysis: Codable, Equatable {
    public let questionId: String
    public let textHash: String
    public let promptVersion: String
    public let language: String
    public let coreSentence: EnglishGrammarSentencePair?
    public let simpleSentences: [EnglishGrammarSentencePair]?

    public init(
        questionId: String,
        textHash: String,
        promptVersion: String,
        language: String,
        coreSentence: EnglishGrammarSentencePair?,
        simpleSentences: [EnglishGrammarSentencePair]?
    ) {
        self.questionId = questionId
        self.textHash = textHash
        self.promptVersion = promptVersion
        self.language = language
        self.coreSentence = coreSentence
        self.simpleSentences = simpleSentences
    }

    enum CodingKeys: String, CodingKey {
        case questionId = "question_id"
        case textHash = "text_hash"
        case promptVersion = "prompt_version"
        case language
        case coreSentence = "core_sentence"
        case simpleSentences = "simple_sentences"
    }
}

