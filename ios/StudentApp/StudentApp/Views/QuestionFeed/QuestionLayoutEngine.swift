import SwiftUI
import UIKit
import StudentCore

enum QuestionBodyLayout: Equatable {
    case short
    case long(stemPages: [String])
}

@MainActor
final class QuestionLayoutEngine {
    static let shared = QuestionLayoutEngine()

    private var cache: [QuestionLayoutKey: QuestionBodyLayout] = [:]

    private init() {}

    func layout(
        question: Question,
        size: CGSize,
        colorScheme: ColorScheme,
        displayScale: CGFloat,
        textColor: Color
    ) async -> QuestionBodyLayout {
        let width = max(1, size.width)
        let height = max(1, size.height)
        let key = QuestionLayoutKey(
            questionId: question.id,
            widthBucket: Int(width.rounded(.up)),
            heightBucket: Int(height.rounded(.up)),
            scheme: colorScheme == .dark ? "dark" : "light",
            scaleBucket: String(format: "%.2f", displayScale)
        )
        if let cached = cache[key] {
            return cached
        }

        let textColorHex = ColorHexBuilder.hex(for: textColor, scheme: colorScheme)
        let stemTextWidth = max(1, width - AppMetrics.cardPadding * 2)
        let stemTextHeight = await MathTextMeasurer.shared.measure(
            text: question.stem,
            style: .questionStem,
            width: stemTextWidth,
            colorScheme: colorScheme,
            displayScale: displayScale,
            textColorHex: textColorHex
        )
        let stemCardHeight = stemTextHeight + AppMetrics.cardPadding * 2
        let answerHeight = await measureAnswerHeight(
            question: question,
            width: width,
            colorScheme: colorScheme,
            displayScale: displayScale,
            textColorHex: textColorHex
        )

        let totalHeight = stemCardHeight + answerHeight + AppMetrics.sectionSpacing
        if totalHeight <= height {
            let layout: QuestionBodyLayout = .short
            cache[key] = layout
            return layout
        }

        let pageTextHeight = max(1, height - AppMetrics.cardPadding * 2)
        let stemPages = await paginateStem(
            text: question.stem,
            width: stemTextWidth,
            height: pageTextHeight,
            colorScheme: colorScheme,
            displayScale: displayScale,
            textColorHex: textColorHex
        )
        let layout: QuestionBodyLayout = .long(stemPages: stemPages)
        cache[key] = layout
        return layout
    }

    private func measureAnswerHeight(
        question: Question,
        width: CGFloat,
        colorScheme: ColorScheme,
        displayScale: CGFloat,
        textColorHex: String
    ) async -> CGFloat {
        if let options = question.options, !options.isEmpty {
            let textWidth = max(1, width - AppMetrics.rowPaddingHorizontal * 2 - AppMetrics.badgeSize - 12)
            var total: CGFloat = 0
            for option in options {
                let optionHeight = await MathTextMeasurer.shared.measure(
                    text: option.content,
                    style: .option,
                    width: textWidth,
                    colorScheme: colorScheme,
                    displayScale: displayScale,
                    textColorHex: textColorHex
                )
                let contentHeight = max(AppMetrics.badgeSize, optionHeight)
                let rowHeight = contentHeight + AppMetrics.rowPaddingVertical * 2
                total += rowHeight
            }
            if options.count > 1 {
                total += CGFloat(options.count - 1) * 10
            }
            return total
        }

        let font = UIFont.preferredFont(forTextStyle: .body)
        let contentHeight = max(22, font.lineHeight)
        return contentHeight + AppMetrics.fieldPaddingVertical * 2
    }

    private func paginateStem(
        text: String,
        width: CGFloat,
        height: CGFloat,
        colorScheme: ColorScheme,
        displayScale: CGFloat,
        textColorHex: String
    ) async -> [String] {
        var blocks = makeBlocks(text: text)
        if blocks.isEmpty {
            return [text]
        }

        var pages: [String] = []
        var index = 0
        while index < blocks.count {
            var low = 1
            var high = blocks.count - index
            var best = 0

            while low <= high {
                let mid = (low + high) / 2
                let candidate = blocks[index..<(index + mid)].joined()
                let candidateHeight = await MathTextMeasurer.shared.measure(
                    text: candidate,
                    style: .questionStem,
                    width: width,
                    colorScheme: colorScheme,
                    displayScale: displayScale,
                    textColorHex: textColorHex
                )
                if candidateHeight <= height {
                    best = mid
                    low = mid + 1
                } else {
                    high = mid - 1
                }
            }

            if best == 0 {
                let exploded = explodeBlock(blocks[index])
                if exploded.count > 1 {
                    blocks.replaceSubrange(index...index, with: exploded)
                    continue
                }
                pages.append(blocks[index].trimmingCharacters(in: .whitespacesAndNewlines))
                index += 1
                continue
            }

            let pageText = blocks[index..<(index + best)].joined()
            pages.append(pageText.trimmingCharacters(in: .whitespacesAndNewlines))
            index += best
        }

        return pages.isEmpty ? [text] : pages
    }

    private func makeBlocks(text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let paragraphs = normalized.components(separatedBy: "\n\n")
        var blocks: [String] = []
        for (index, paragraph) in paragraphs.enumerated() {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let suffix = index == paragraphs.count - 1 ? "" : "\n\n"
            blocks.append(trimmed + suffix)
        }
        return blocks
    }

    private func explodeBlock(_ block: String) -> [String] {
        let trailing = block.reversed().prefix { $0 == "\n" }.reversed()
        let body = block.dropLast(trailing.count)
        let lines = body.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count > 1 else { return [block] }
        var blocks: [String] = []
        for (index, line) in lines.enumerated() {
            let suffix = index == lines.count - 1 ? String(trailing) : "\n"
            blocks.append(line + suffix)
        }
        return blocks
    }
}

private struct QuestionLayoutKey: Hashable {
    let questionId: String
    let widthBucket: Int
    let heightBucket: Int
    let scheme: String
    let scaleBucket: String
}
