import Combine
import SwiftUI
import UIKit
import StudentCore

enum QuestionAnswerPage: Equatable {
    case options([QuestionOption])
    case freeResponse
}

enum QuestionBodyLayout: Equatable {
    case short
    case long(stemPages: [String], answerPages: [QuestionAnswerPage])
}

@MainActor
final class QuestionLayoutEngine {
    static let shared = QuestionLayoutEngine()

    private let cache = NSCache<NSString, QuestionLayoutBox>()

    private init() {
        cache.countLimit = 120
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    @objc private func handleMemoryWarning() {
        cache.removeAllObjects()
    }

    private func cacheKey(
        questionId: String,
        width: CGFloat,
        height: CGFloat,
        colorScheme: ColorScheme,
        displayScale: CGFloat
    ) -> String {
        QuestionLayoutKey(
            questionId: questionId,
            widthBucket: Int(width.rounded(.up)),
            heightBucket: Int(height.rounded(.up)),
            scheme: colorScheme == .dark ? "dark" : "light",
            scaleBucket: String(format: "%.2f", displayScale)
        ).cacheKey
    }

    func cachedLayout(
        question: Question,
        size: CGSize,
        colorScheme: ColorScheme,
        displayScale: CGFloat
    ) -> QuestionBodyLayout? {
        let width = max(1, size.width)
        let height = max(1, size.height)
        let key = cacheKey(
            questionId: question.id,
            width: width,
            height: height,
            colorScheme: colorScheme,
            displayScale: displayScale
        )
        return cache.object(forKey: key as NSString)?.value
    }

    func prefetch(
        question: Question,
        size: CGSize,
        colorScheme: ColorScheme,
        displayScale: CGFloat,
        textColor: Color
    ) async {
        if cachedLayout(question: question, size: size, colorScheme: colorScheme, displayScale: displayScale) != nil {
            return
        }
        _ = await layout(
            question: question,
            size: size,
            colorScheme: colorScheme,
            displayScale: displayScale,
            textColor: textColor
        )
    }

    func layout(
        question: Question,
        size: CGSize,
        colorScheme: ColorScheme,
        displayScale: CGFloat,
        textColor: Color
    ) async -> QuestionBodyLayout {
        let signpostId = PerformanceSignpost.begin("QuestionLayout")
        defer { PerformanceSignpost.end("QuestionLayout", id: signpostId) }
        let width = max(1, size.width)
        let height = max(1, size.height)
        let key = cacheKey(
            questionId: question.id,
            width: width,
            height: height,
            colorScheme: colorScheme,
            displayScale: displayScale
        )
        if let cached = cache.object(forKey: key as NSString)?.value {
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
            cache.setObject(QuestionLayoutBox(layout), forKey: key as NSString)
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
        let answerPages = await paginateAnswerPages(
            question: question,
            width: width,
            height: height,
            colorScheme: colorScheme,
            displayScale: displayScale,
            textColorHex: textColorHex
        )
        let layout: QuestionBodyLayout = .long(stemPages: stemPages, answerPages: answerPages)
        cache.setObject(QuestionLayoutBox(layout), forKey: key as NSString)
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
                total += CGFloat(options.count - 1) * AppMetrics.rowSpacing
            }
            return total
        }

        let font = UIFont.preferredFont(forTextStyle: .body)
        let contentHeight = max(22, font.lineHeight)
        return contentHeight + AppMetrics.fieldPaddingVertical * 2
    }

    private func paginateAnswerPages(
        question: Question,
        width: CGFloat,
        height: CGFloat,
        colorScheme: ColorScheme,
        displayScale: CGFloat,
        textColorHex: String
    ) async -> [QuestionAnswerPage] {
        if let options = question.options, !options.isEmpty {
            let optionPages = await paginateOptions(
                options,
                width: width,
                height: height,
                colorScheme: colorScheme,
                displayScale: displayScale,
                textColorHex: textColorHex
            )
            if optionPages.isEmpty {
                return [.options(options)]
            }
            return optionPages.map { .options($0) }
        }

        return [.freeResponse]
    }

    private func paginateOptions(
        _ options: [QuestionOption],
        width: CGFloat,
        height: CGFloat,
        colorScheme: ColorScheme,
        displayScale: CGFloat,
        textColorHex: String
    ) async -> [[QuestionOption]] {
        let textWidth = max(1, width - AppMetrics.rowPaddingHorizontal * 2 - AppMetrics.badgeSize - 12)
        var measured: [(QuestionOption, CGFloat)] = []
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
            measured.append((option, rowHeight))
        }

        let availableHeight = max(1, height)
        let spacing = AppMetrics.rowSpacing
        var pages: [[QuestionOption]] = []
        var current: [QuestionOption] = []
        var currentHeight: CGFloat = 0

        for (option, rowHeight) in measured {
            let nextHeight = current.isEmpty ? rowHeight : (currentHeight + spacing + rowHeight)
            if !current.isEmpty && nextHeight > availableHeight {
                pages.append(current)
                current = [option]
                currentHeight = rowHeight
            } else {
                current.append(option)
                currentHeight = nextHeight
            }
        }

        if !current.isEmpty {
            pages.append(current)
        }

        return pages
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

    var cacheKey: String {
        [
            questionId,
            String(widthBucket),
            String(heightBucket),
            scheme,
            scaleBucket
        ].joined(separator: "|")
    }
}

private final class QuestionLayoutBox: NSObject {
    let value: QuestionBodyLayout

    init(_ value: QuestionBodyLayout) {
        self.value = value
    }
}
