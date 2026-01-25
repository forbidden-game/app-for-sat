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

public struct EnglishGrammarAnalysis: Codable, Equatable {
    public let questionId: String
    public let textHash: String
    public let promptVersion: String
    public let language: String
    public let passage: String?
    public let prompt: String
    public let sentences: [EnglishGrammarSentence]
    public let importantWords: [EnglishImportantWord]

    public init(
        questionId: String,
        textHash: String,
        promptVersion: String,
        language: String,
        passage: String?,
        prompt: String,
        sentences: [EnglishGrammarSentence],
        importantWords: [EnglishImportantWord]
    ) {
        self.questionId = questionId
        self.textHash = textHash
        self.promptVersion = promptVersion
        self.language = language
        self.passage = passage
        self.prompt = prompt
        self.sentences = sentences
        self.importantWords = importantWords
    }

    enum CodingKeys: String, CodingKey {
        case questionId = "question_id"
        case textHash = "text_hash"
        case promptVersion = "prompt_version"
        case language
        case passage
        case prompt
        case sentences
        case importantWords = "important_words"
    }
}

public struct EnglishGrammarSentence: Codable, Equatable, Identifiable {
    public let sentenceIndex: Int
    public let source: String
    public let text: String
    public let components: [EnglishGrammarComponent]

    public var id: Int { sentenceIndex }

    public init(sentenceIndex: Int, source: String, text: String, components: [EnglishGrammarComponent]) {
        self.sentenceIndex = sentenceIndex
        self.source = source
        self.text = text
        self.components = components
    }

    enum CodingKeys: String, CodingKey {
        case sentenceIndex = "sentence_index"
        case source
        case text
        case components
    }
}

public struct EnglishGrammarComponent: Codable, Equatable, Identifiable {
    public let id: String
    public let type: String
    public let start: Int
    public let end: Int
    public let labelEn: String
    public let labelZh: String
    public let explanationEn: String?
    public let explanationZh: String?

    public init(
        id: String,
        type: String,
        start: Int,
        end: Int,
        labelEn: String,
        labelZh: String,
        explanationEn: String?,
        explanationZh: String?
    ) {
        self.id = id
        self.type = type
        self.start = start
        self.end = end
        self.labelEn = labelEn
        self.labelZh = labelZh
        self.explanationEn = explanationEn
        self.explanationZh = explanationZh
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case start
        case end
        case labelEn = "label_en"
        case labelZh = "label_zh"
        case explanationEn = "explanation_en"
        case explanationZh = "explanation_zh"
    }
}

public struct EnglishImportantWord: Codable, Equatable, Identifiable {
    public let word: String
    public let lemma: String?
    public let partOfSpeech: String?
    public let meaningEn: String?
    public let meaningZh: String?
    public let whyEn: String?
    public let whyZh: String?

    public var id: String { lemma ?? word }

    public init(
        word: String,
        lemma: String?,
        partOfSpeech: String?,
        meaningEn: String?,
        meaningZh: String?,
        whyEn: String?,
        whyZh: String?
    ) {
        self.word = word
        self.lemma = lemma
        self.partOfSpeech = partOfSpeech
        self.meaningEn = meaningEn
        self.meaningZh = meaningZh
        self.whyEn = whyEn
        self.whyZh = whyZh
    }

    enum CodingKeys: String, CodingKey {
        case word
        case lemma
        case partOfSpeech = "pos"
        case meaningEn = "meaning_en"
        case meaningZh = "meaning_zh"
        case whyEn = "why_en"
        case whyZh = "why_zh"
    }
}

public enum EnglishGrammarAnalysisDefaults {
    public static let promptVersion = "english-grammar-v1"
}
