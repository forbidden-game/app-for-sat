import Foundation

public struct DerivedQuestionText: Equatable, Sendable {
    public let prompt: String
    public let passage: String?

    public init(prompt: String, passage: String?) {
        self.prompt = prompt
        self.passage = passage
    }
}

public enum QuestionTextDeriver {
    public static func derive(from stem: String) -> DerivedQuestionText {
        let trimmedStem = stem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedStem.isEmpty else {
            return DerivedQuestionText(prompt: "", passage: nil)
        }

        let promptEndIndex = preferredPromptEndIndex(in: trimmedStem) ?? trimmedStem.index(before: trimmedStem.endIndex)
        let promptStartIndex = sentenceStartIndex(in: trimmedStem, endingAt: promptEndIndex)

        let promptRaw = String(trimmedStem[promptStartIndex...promptEndIndex])
        let prompt = normalizeWhitespace(in: promptRaw)

        let passageRaw = String(trimmedStem[..<promptStartIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let passage: String? = passageRaw.isEmpty ? nil : passageRaw

        return DerivedQuestionText(prompt: prompt, passage: passage)
    }

    private static func normalizeWhitespace(in text: String) -> String {
        text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func sentenceStartIndex(in text: String, endingAt endIndex: String.Index) -> String.Index {
        var index = endIndex
        while index > text.startIndex {
            let prev = text.index(before: index)
            let ch = text[prev]
            if ch == "." || ch == "!" || ch == "?" || ch == "\n" {
                return text.index(after: prev)
            }
            index = prev
        }
        return text.startIndex
    }

    private static func preferredPromptEndIndex(in text: String) -> String.Index? {
        if let q = text.lastIndex(of: "?") { return q }
        if let ex = text.lastIndex(of: "!") { return ex }
        if let dot = text.lastIndex(of: ".") { return dot }
        return nil
    }
}
