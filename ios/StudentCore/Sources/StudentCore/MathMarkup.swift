import Foundation

public enum MathMarkupSegment: Equatable {
    case text(String)
    case inlineMath(String)
    case blockMath(String)
}

public struct MathMarkupDocument: Equatable {
    public let segments: [MathMarkupSegment]
    public let normalizedText: String
    public let plainText: String
    public let requiresMathRendering: Bool
    public let warnings: [MathMarkupWarning]
}

public enum MathMarkupWarning: Equatable {
    case unbalancedDelimiters
    case unknownCommand(String)
    case invalidEnvironment(String)
}

public protocol MathMarkupParsing {
    func parse(_ text: String) -> MathMarkupDocument
}

public struct MathMarkupParser: MathMarkupParsing {
    public init() {}

    public func parse(_ text: String) -> MathMarkupDocument {
        guard !text.isEmpty else {
            return MathMarkupDocument(
                segments: [],
                normalizedText: "",
                plainText: "",
                requiresMathRendering: false,
                warnings: []
            )
        }

        var segments: [MathMarkupSegment] = []
        var warnings: [MathMarkupWarning] = []

        let scanner = Scanner(text: text)
        var index = scanner.startIndex
        var lastTextStart = index

        func flushText(upTo end: String.Index) {
            guard lastTextStart < end else { return }
            let textSegment = String(text[lastTextStart..<end])
            segments.append(.text(textSegment))
            lastTextStart = end
        }

        while index < scanner.endIndex {
            if scanner.hasPrefix("$$", at: index), !scanner.isEscaped(at: index) {
                if let close = scanner.findDelimiter("$$", from: scanner.advance(index, by: 2)) {
                    flushText(upTo: index)
                    let contentRange = scanner.advance(index, by: 2)..<close
                    let content = normalizeMathContent(String(text[contentRange]))
                    segments.append(.blockMath(content))
                    index = scanner.advance(close, by: 2)
                    lastTextStart = index
                    continue
                } else {
                    warnings.append(.unbalancedDelimiters)
                    index = scanner.advance(index, by: 2)
                    continue
                }
            }

            if scanner.hasPrefix("\\[", at: index) {
                if let close = scanner.findDelimiter("\\]", from: scanner.advance(index, by: 2)) {
                    flushText(upTo: index)
                    let contentRange = scanner.advance(index, by: 2)..<close
                    let content = normalizeMathContent(String(text[contentRange]))
                    segments.append(.blockMath(content))
                    index = scanner.advance(close, by: 2)
                    lastTextStart = index
                    continue
                } else {
                    warnings.append(.unbalancedDelimiters)
                    index = scanner.advance(index, by: 2)
                    continue
                }
            }

            if scanner.hasPrefix("\\begin{", at: index) {
                if let envMatch = scanner.parseEnvironment(from: index) {
                    let name = envMatch.name
                    if !MathEnvironment.allowed.contains(name) {
                        warnings.append(.invalidEnvironment(name))
                        if let endIndex = envMatch.endIndex {
                            index = endIndex
                        } else {
                            warnings.append(.unbalancedDelimiters)
                            index = scanner.advance(index, by: 7)
                        }
                        continue
                    }

                    guard let endIndex = envMatch.endIndex else {
                        warnings.append(.unbalancedDelimiters)
                        index = scanner.advance(index, by: 7)
                        continue
                    }

                    flushText(upTo: index)
                    let normalizedName = MathEnvironment.normalizedName(for: name)
                    let content = String(text[envMatch.contentRange])
                    let normalizedContent = normalizeMathContent(content)
                    let wrapped = "\\begin{\(normalizedName)}\(normalizedContent)\\end{\(normalizedName)}"
                    segments.append(.blockMath(wrapped))
                    index = endIndex
                    lastTextStart = index
                    continue
                }
            }

            if scanner.hasPrefix("$", at: index), !scanner.isEscaped(at: index) {
                if let close = scanner.findDelimiter("$", from: scanner.advance(index, by: 1)) {
                    flushText(upTo: index)
                    let contentRange = scanner.advance(index, by: 1)..<close
                    let content = normalizeMathContent(String(text[contentRange]))
                    segments.append(.inlineMath(content))
                    index = scanner.advance(close, by: 1)
                    lastTextStart = index
                    continue
                } else {
                    warnings.append(.unbalancedDelimiters)
                    index = scanner.advance(index, by: 1)
                    continue
                }
            }

            if scanner.hasPrefix("\\(", at: index) {
                if let close = scanner.findDelimiter("\\)", from: scanner.advance(index, by: 2)) {
                    flushText(upTo: index)
                    let contentRange = scanner.advance(index, by: 2)..<close
                    let content = normalizeMathContent(String(text[contentRange]))
                    segments.append(.inlineMath(content))
                    index = scanner.advance(close, by: 2)
                    lastTextStart = index
                    continue
                } else {
                    warnings.append(.unbalancedDelimiters)
                    index = scanner.advance(index, by: 2)
                    continue
                }
            }

            index = scanner.advance(index, by: 1)
        }

        flushText(upTo: scanner.endIndex)

        let normalizedText = buildNormalizedText(from: segments)
        let plainText = buildPlainText(from: segments)
        let requiresMathRendering = segments.contains { segment in
            switch segment {
            case .text:
                return false
            case .inlineMath, .blockMath:
                return true
            }
        }

        var commandWarnings = warnings
        for command in unknownCommands(in: segments) {
            commandWarnings.append(.unknownCommand(command))
        }

        return MathMarkupDocument(
            segments: segments,
            normalizedText: normalizedText,
            plainText: plainText,
            requiresMathRendering: requiresMathRendering,
            warnings: commandWarnings
        )
    }
}

private struct Scanner {
    let text: String
    let startIndex: String.Index
    let endIndex: String.Index

    init(text: String) {
        self.text = text
        startIndex = text.startIndex
        endIndex = text.endIndex
    }

    func advance(_ index: String.Index, by offset: Int) -> String.Index {
        text.index(index, offsetBy: offset, limitedBy: endIndex) ?? endIndex
    }

    func hasPrefix(_ prefix: String, at index: String.Index) -> Bool {
        text[index...].hasPrefix(prefix)
    }

    func isEscaped(at index: String.Index) -> Bool {
        var count = 0
        var cursor = index
        while cursor > startIndex {
            cursor = text.index(before: cursor)
            if text[cursor] == "\\" {
                count += 1
            } else {
                break
            }
        }
        return count % 2 == 1
    }

    func findDelimiter(_ delimiter: String, from start: String.Index) -> String.Index? {
        var cursor = start
        while cursor < endIndex {
            if hasPrefix(delimiter, at: cursor), !isEscaped(at: cursor) {
                return cursor
            }
            cursor = advance(cursor, by: 1)
        }
        return nil
    }

    func parseEnvironment(from index: String.Index) -> EnvironmentMatch? {
        guard hasPrefix("\\begin{", at: index) else { return nil }
        let nameStart = advance(index, by: 7)
        guard let nameEnd = text[nameStart...].firstIndex(of: "}") else { return nil }
        let name = String(text[nameStart..<nameEnd])
        let contentStart = advance(nameEnd, by: 1)
        let endToken = "\\end{\(name)}"
        if let endRange = text.range(of: endToken, range: contentStart..<endIndex) {
            return EnvironmentMatch(
                name: name,
                contentRange: contentStart..<endRange.lowerBound,
                endIndex: endRange.upperBound
            )
        }
        return EnvironmentMatch(name: name, contentRange: contentStart..<endIndex, endIndex: nil)
    }
}

private struct EnvironmentMatch {
    let name: String
    let contentRange: Range<String.Index>
    let endIndex: String.Index?
}

private enum MathEnvironment {
    static let allowed: Set<String> = [
        "align", "align*", "aligned",
        "equation", "equation*",
        "gather", "gather*",
        "multline", "multline*",
        "eqnarray", "eqnarray*",
        "cases",
        "matrix", "pmatrix", "bmatrix", "vmatrix", "Vmatrix", "smallmatrix",
        "split"
    ]

    static func normalizedName(for name: String) -> String {
        switch name {
        case "align", "align*":
            return "aligned"
        case "equation*":
            return "equation"
        case "gather*":
            return "gather"
        case "multline*":
            return "multline"
        case "eqnarray*":
            return "eqnarray"
        default:
            return name
        }
    }
}

private func normalizeMathContent(_ content: String) -> String {
    var updated = content
    updated = updated.replacingOccurrences(of: "\\begin{align*}", with: "\\begin{aligned}")
    updated = updated.replacingOccurrences(of: "\\end{align*}", with: "\\end{aligned}")
    updated = updated.replacingOccurrences(of: "\\begin{align}", with: "\\begin{aligned}")
    updated = updated.replacingOccurrences(of: "\\end{align}", with: "\\end{aligned}")
    updated = updated.replacingOccurrences(of: "\\begin{equation*}", with: "\\begin{equation}")
    updated = updated.replacingOccurrences(of: "\\end{equation*}", with: "\\end{equation}")
    return updated
}

private func buildNormalizedText(from segments: [MathMarkupSegment]) -> String {
    var result = ""
    for segment in segments {
        switch segment {
        case .text(let text):
            result.append(text)
        case .inlineMath(let latex):
            result.append("$")
            result.append(latex)
            result.append("$")
        case .blockMath(let latex):
            result.append("$$")
            result.append(latex)
            result.append("$$")
        }
    }
    return result
}

private func buildPlainText(from segments: [MathMarkupSegment]) -> String {
    var result = ""
    for segment in segments {
        switch segment {
        case .text(let text):
            result.append(text)
        case .inlineMath(let latex), .blockMath(let latex):
            if !result.isEmpty { result.append(" ") }
            result.append(sanitizeMathText(latex))
        }
    }
    return result.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
}

private func sanitizeMathText(_ content: String) -> String {
    var updated = content
    updated = updated.replacingOccurrences(of: "\\\\", with: "\n")
    updated = updated.replacingOccurrences(of: "\\begin{", with: "")
    updated = updated.replacingOccurrences(of: "\\end{", with: "")
    updated = updated.replacingOccurrences(of: "}", with: "")
    updated = updated.replacingOccurrences(of: "{", with: "")
    updated = updated.replacingOccurrences(of: "\\", with: "")
    updated = updated.replacingOccurrences(of: "\n", with: " ")
    return updated.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func unknownCommands(in segments: [MathMarkupSegment]) -> [String] {
    let allowedCommands: Set<String> = [
        "frac", "sqrt", "pi", "alpha", "beta", "gamma", "theta",
        "sin", "cos", "tan", "log", "ln", "cdot", "times",
        "leq", "geq", "neq", "pm", "left", "right",
        "text", "mathrm", "mathbf", "overline", "underline",
        "begin", "end"
    ]
    guard let regex = try? NSRegularExpression(pattern: #"\\([A-Za-z]+)"#, options: []) else {
        return []
    }
    var unknown: Set<String> = []
    for segment in segments {
        let content: String
        switch segment {
        case .text:
            continue
        case .inlineMath(let latex), .blockMath(let latex):
            content = latex
        }
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        let matches = regex.matches(in: content, options: [], range: range)
        for match in matches {
            guard match.numberOfRanges > 1,
                  let commandRange = Range(match.range(at: 1), in: content) else { continue }
            let command = String(content[commandRange])
            if !allowedCommands.contains(command) {
                unknown.insert(command)
            }
        }
    }
    return Array(unknown).sorted()
}
