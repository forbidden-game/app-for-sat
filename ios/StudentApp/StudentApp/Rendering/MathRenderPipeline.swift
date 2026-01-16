import Foundation
import StudentCore
import SwiftUI
import WebKit

struct MathRenderRequest: Hashable {
    let text: String
    let style: MathTextStyle
    let width: CGFloat
    let colorScheme: ColorScheme
    let displayScale: CGFloat
    let textColorHex: String

    init(
        text: String,
        style: MathTextStyle,
        width: CGFloat,
        colorScheme: ColorScheme,
        displayScale: CGFloat,
        textColorHex: String
    ) {
        self.text = text
        self.style = style
        self.width = width
        self.colorScheme = colorScheme
        self.displayScale = displayScale
        self.textColorHex = textColorHex
    }

    static func == (lhs: MathRenderRequest, rhs: MathRenderRequest) -> Bool {
        lhs.text == rhs.text &&
        lhs.style == rhs.style &&
        lhs.width == rhs.width &&
        lhs.colorScheme == rhs.colorScheme &&
        lhs.displayScale == rhs.displayScale &&
        lhs.textColorHex == rhs.textColorHex
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(text)
        hasher.combine(style.cacheKey)
        hasher.combine(width)
        hasher.combine(colorScheme == .dark ? "dark" : "light")
        hasher.combine(displayScale)
        hasher.combine(textColorHex)
    }
}

enum MathRenderPlan: Equatable {
    case plainText(AttributedString)
    case webHTML(MathHTMLPayload)
    case nativeLabel(MathNativePayload)
}

struct MathHTMLPayload: Equatable {
    let html: String
    let accessibilityText: String
    let estimatedHeight: CGFloat
}

struct MathNativePayload: Equatable {
    let latex: String
    let plainText: String
    let style: MathTextStyle
    let isDisplay: Bool
}

enum MathRenderFailure: Error, Equatable {
    case unsupported
    case empty
    case renderFailed(String)
}

protocol MathNativeRendering {
    func payload(
        latex: String,
        plainText: String,
        style: MathTextStyle,
        isDisplay: Bool
    ) -> MathNativePayload?
}

protocol MathRenderPlanning {
    func plan(for request: MathRenderRequest) -> MathRenderPlan
}

protocol MathRenderer {
    func render(_ payload: MathHTMLPayload, into webView: WKWebView) async throws -> CGFloat
}

protocol MathWebViewPoolProviding {
    func acquire() -> WKWebView
    func release(_ webView: WKWebView)
}

struct MathRenderPolicy {
    var maxInlineCharsForNative: Int = 600
    var allowNativeWithUnknownCommands = false
    var allowNativeWithTextSegments = false

    init() {}
}

final class MathRenderPlanner: MathRenderPlanning {
    private let parser: MathMarkupParsing
    private let cache: MathRenderCache
    private let policy: MathRenderPolicy
    private let nativeRenderer: MathNativeRendering?

    init(
        parser: MathMarkupParsing = MathMarkupParser(),
        cache: MathRenderCache = .shared,
        policy: MathRenderPolicy = MathRenderPolicy(),
        nativeRenderer: MathNativeRendering? = nil
    ) {
        self.parser = parser
        self.cache = cache
        self.policy = policy
        self.nativeRenderer = nativeRenderer
    }

    func plan(for request: MathRenderRequest) -> MathRenderPlan {
        let cacheKey = MathRenderKeyBuilder.key(for: request)
        if let cached = cache.plan(forKey: cacheKey) {
            return cached
        }

        let doc = parser.parse(request.text)
        if !doc.requiresMathRendering {
            let rendered = InlineMarkdownRenderer.render(doc.plainText)
            let plan = MathRenderPlan.plainText(rendered)
            cache.store(plan, forKey: cacheKey)
            return plan
        }

        if let nativeRenderer,
           let latex = nativeLatex(from: doc),
           shouldUseNative(doc: doc, latex: latex, policy: policy) {
            if let payload = nativeRenderer.payload(
                latex: latex,
                plainText: doc.plainText,
                style: request.style,
                isDisplay: false
            ) {
                let plan = MathRenderPlan.nativeLabel(payload)
                cache.store(plan, forKey: cacheKey)
                return plan
            }
        }

        let html = MathHTMLBuilderV2.html(
            for: doc,
            style: request.style,
            colorScheme: request.colorScheme,
            displayScale: request.displayScale,
            textColorHex: request.textColorHex
        )
        let estimatedHeight = MathTextHeightEstimator.estimatedHeight(
            for: doc.plainText,
            style: request.style
        )
        let payload = MathHTMLPayload(
            html: html,
            accessibilityText: doc.plainText,
            estimatedHeight: estimatedHeight
        )
        let plan = MathRenderPlan.webHTML(payload)
        cache.store(plan, forKey: cacheKey)
        return plan
    }

    private func shouldUseNative(doc: MathMarkupDocument, latex: String, policy: MathRenderPolicy) -> Bool {
        var hasTextSegments = false
        var hasBlockMath = false
        var totalInlineChars = 0
        var mathSegments = 0

        for segment in doc.segments {
            switch segment {
            case .text(let text):
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    hasTextSegments = true
                }
            case .blockMath(let latex):
                hasBlockMath = true
                mathSegments += 1
                totalInlineChars += latex.count
            case .inlineMath(let latex):
                mathSegments += 1
                totalInlineChars += latex.count
            }
        }

        if hasBlockMath {
            return false
        }
        if mathSegments != 1 {
            return false
        }
        if hasTextSegments && !policy.allowNativeWithTextSegments {
            return false
        }
        if totalInlineChars > policy.maxInlineCharsForNative {
            return false
        }
        if doc.warnings.contains(where: { if case .unbalancedDelimiters = $0 { return true } else { return false } }) {
            return false
        }
        if doc.warnings.contains(where: { if case .invalidEnvironment = $0 { return true } else { return false } }) {
            return false
        }
        if !SwiftMathLatexValidator.isSafe(latex) {
            return false
        }
        if !policy.allowNativeWithUnknownCommands {
            if doc.warnings.contains(where: { if case .unknownCommand = $0 { return true } else { return false } }) {
                return false
            }
        }
        return true
    }

    private func nativeLatex(from doc: MathMarkupDocument) -> String? {
        var parts: [String] = []
        for segment in doc.segments {
            switch segment {
            case .text:
                continue
            case .inlineMath(let latex), .blockMath(let latex):
                let trimmed = latex.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    parts.append(trimmed)
                }
            }
        }
        guard parts.count == 1 else { return nil }
        return parts[0]
    }
}

final class MathRenderCache {
    static let shared = MathRenderCache()

    private let planCache: NSCache<NSString, MathRenderPlanBox>

    init() {
        planCache = NSCache<NSString, MathRenderPlanBox>()
        planCache.countLimit = 200
    }

    func plan(forKey key: String) -> MathRenderPlan? {
        planCache.object(forKey: key as NSString)?.value
    }

    func store(_ plan: MathRenderPlan, forKey key: String) {
        planCache.setObject(MathRenderPlanBox(plan), forKey: key as NSString)
    }
}

private final class MathRenderPlanBox: NSObject {
    let value: MathRenderPlan

    init(_ value: MathRenderPlan) {
        self.value = value
    }
}

enum MathRenderKeyBuilder {
    static func key(for request: MathRenderRequest) -> String {
        let widthBucket = ceil(request.width)
        let scheme = request.colorScheme == .dark ? "dark" : "light"
        return [
            request.style.cacheKey,
            String(format: "%.0f", widthBucket),
            scheme,
            String(format: "%.2f", request.displayScale),
            request.text
        ].joined(separator: "|")
    }
}

private enum MathTextHeightEstimator {
    static func estimatedHeight(for text: String, style: MathTextStyle) -> CGFloat {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return style.fontSize * style.lineHeight }
        let approxCharsPerLine: CGFloat = 28
        let estimatedLines = ceil(CGFloat(trimmed.count) / approxCharsPerLine)
        let lineHeight = style.fontSize * style.lineHeight
        return max(lineHeight, estimatedLines * lineHeight)
    }
}

private enum InlineMarkdownRenderer {
    static func render(_ text: String) -> AttributedString {
        let normalized = normalizeListMarkers(in: text)
        if let rendered = try? AttributedString(
            markdown: normalized,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return rendered
        }
        return AttributedString(normalized)
    }

    private static func normalizeListMarkers(in text: String) -> String {
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        let normalized = lines.map { line -> String in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let content = trimmed.dropFirst(2)
                return "• \(content)"
            }
            if let dotRange = trimmed.range(of: ". "), trimmed.startIndex < dotRange.lowerBound {
                let prefix = trimmed[..<dotRange.lowerBound]
                if prefix.allSatisfy({ $0.isNumber }) {
                    let content = trimmed[dotRange.upperBound...]
                    return "• \(content)"
                }
            }
            return String(line)
        }
        return normalized.joined(separator: "\n")
    }
}
