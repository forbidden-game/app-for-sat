import Foundation
import StudentCore
import SwiftUI
import WebKit

public struct MathRenderRequest: Hashable {
    public let text: String
    public let style: MathTextStyle
    public let width: CGFloat
    public let colorScheme: ColorScheme
    public let displayScale: CGFloat

    public init(
        text: String,
        style: MathTextStyle,
        width: CGFloat,
        colorScheme: ColorScheme,
        displayScale: CGFloat
    ) {
        self.text = text
        self.style = style
        self.width = width
        self.colorScheme = colorScheme
        self.displayScale = displayScale
    }

    public static func == (lhs: MathRenderRequest, rhs: MathRenderRequest) -> Bool {
        lhs.text == rhs.text &&
        lhs.style == rhs.style &&
        lhs.width == rhs.width &&
        lhs.colorScheme == rhs.colorScheme &&
        lhs.displayScale == rhs.displayScale
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(text)
        hasher.combine(style.cacheKey)
        hasher.combine(width)
        hasher.combine(colorScheme == .dark ? "dark" : "light")
        hasher.combine(displayScale)
    }
}

public enum MathRenderPlan: Equatable {
    case plainText(AttributedString)
    case webHTML(MathHTMLPayload)
    case nativeLabel(MathNativePayload)
}

public struct MathHTMLPayload: Equatable {
    public let html: String
    public let accessibilityText: String
    public let estimatedHeight: CGFloat
}

public struct MathNativePayload: Equatable {
    public let latex: String
    public let plainText: String
    public let style: MathTextStyle
    public let isDisplay: Bool
}

public enum MathRenderFailure: Error, Equatable {
    case unsupported
    case empty
    case renderFailed(String)
}

public protocol MathNativeRendering {
    func payload(
        latex: String,
        plainText: String,
        style: MathTextStyle,
        isDisplay: Bool
    ) -> MathNativePayload?
}

public protocol MathRenderPlanning {
    func plan(for request: MathRenderRequest) -> MathRenderPlan
}

public protocol MathRenderer {
    func render(_ payload: MathHTMLPayload, into webView: WKWebView) async throws -> CGFloat
}

public protocol MathWebViewPoolProviding {
    func acquire() -> WKWebView
    func release(_ webView: WKWebView)
}

public struct MathRenderPolicy {
    public var maxInlineCharsForNative: Int = 600
    public var allowNativeWithUnknownCommands = false
    public var allowNativeWithTextSegments = false

    public init() {}
}

public final class MathRenderPlanner: MathRenderPlanning {
    private let parser: MathMarkupParsing
    private let cache: MathRenderCache
    private let policy: MathRenderPolicy
    private let nativeRenderer: MathNativeRendering?

    public init(
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

    public func plan(for request: MathRenderRequest) -> MathRenderPlan {
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
           shouldUseNative(doc: doc, policy: policy) {
            let latex = nativeLatex(from: doc)
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
            for: doc.normalizedText,
            style: request.style,
            colorScheme: request.colorScheme,
            displayScale: request.displayScale
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

    private func shouldUseNative(doc: MathMarkupDocument, policy: MathRenderPolicy) -> Bool {
        var hasTextSegments = false
        var hasBlockMath = false
        var totalInlineChars = 0

        for segment in doc.segments {
            switch segment {
            case .text(let text):
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    hasTextSegments = true
                }
            case .blockMath(let latex):
                hasBlockMath = true
                totalInlineChars += latex.count
            case .inlineMath(let latex):
                totalInlineChars += latex.count
            }
        }

        if hasBlockMath {
            return false
        }
        if hasTextSegments && !policy.allowNativeWithTextSegments {
            return false
        }
        if totalInlineChars > policy.maxInlineCharsForNative {
            return false
        }
        if !policy.allowNativeWithUnknownCommands {
            if doc.warnings.contains(where: { if case .unknownCommand = $0 { return true } else { return false } }) {
                return false
            }
        }
        return true
    }

    private func nativeLatex(from doc: MathMarkupDocument) -> String {
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
        return parts.joined(separator: " ")
    }
}

public final class MathRenderCache {
    public static let shared = MathRenderCache()

    private let planCache: NSCache<NSString, MathRenderPlanBox>

    public init() {
        planCache = NSCache<NSString, MathRenderPlanBox>()
        planCache.countLimit = 200
    }

    public func plan(forKey key: String) -> MathRenderPlan? {
        planCache.object(forKey: key as NSString)?.value
    }

    public func store(_ plan: MathRenderPlan, forKey key: String) {
        planCache.setObject(MathRenderPlanBox(plan), forKey: key as NSString)
    }
}

private final class MathRenderPlanBox: NSObject {
    let value: MathRenderPlan

    init(_ value: MathRenderPlan) {
        self.value = value
    }
}

public enum MathRenderKeyBuilder {
    public static func key(for request: MathRenderRequest) -> String {
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
        guard text.contains("*") || text.contains("_") else {
            return AttributedString(text)
        }

        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}
