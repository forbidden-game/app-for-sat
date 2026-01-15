import SwiftUI
import WebKit
import Foundation

struct MathTextView: View {
    let text: String
    var style: MathTextStyle = .body

    @State private var measuredHeight: CGFloat = 1
    @State private var hasRendered = false

    init(text: String, style: MathTextStyle = .body) {
        self.text = text
        self.style = style
        _measuredHeight = State(initialValue: MathTextView.estimatedHeight(for: text, style: style))
        if MathContentDetector.containsMath(text) {
            MathWebViewPrewarmer.prewarm()
        }
    }

    var body: some View {
        if MathContentDetector.containsMath(text) {
            ZStack(alignment: .topLeading) {
                Text(PlainTextSanitizer.sanitize(text))
                    .font(.system(size: style.fontSize, weight: style.fontWeight))
                    .lineSpacing(style.lineSpacing)
                    .multilineTextAlignment(style.textAlignment)
                    .foregroundStyle(AppTheme.textPrimary)
                    .opacity(hasRendered ? 0 : 1)
                    .accessibilityLabel(Text(text))

                MathWebView(
                    html: MathHTMLBuilder.html(for: text, style: style),
                    height: $measuredHeight,
                    rendered: $hasRendered
                )
                .frame(height: max(1, measuredHeight))
                .frame(maxWidth: .infinity, alignment: style.alignment)
                .opacity(hasRendered ? 1 : 0)
            }
            .frame(maxWidth: .infinity, alignment: style.alignment)
        } else {
            Text(InlineMarkdownRenderer.render(PlainTextSanitizer.sanitize(text)))
                .font(.system(size: style.fontSize, weight: style.fontWeight))
                .lineSpacing(style.lineSpacing)
                .multilineTextAlignment(style.textAlignment)
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: style.alignment)
                .accessibilityLabel(Text(text))
        }
    }

    private static func estimatedHeight(for text: String, style: MathTextStyle) -> CGFloat {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return style.fontSize * style.lineHeight }
        let approxCharsPerLine: CGFloat = 28
        let estimatedLines = ceil(CGFloat(trimmed.count) / approxCharsPerLine)
        let lineHeight = style.fontSize * style.lineHeight
        return max(lineHeight, estimatedLines * lineHeight)
    }
}

struct MathTextStyle: Equatable {
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let fontWeightValue: Int
    let lineHeight: CGFloat
    let lineSpacing: CGFloat
    let alignment: Alignment
    let textAlign: String
    let textAlignment: TextAlignment

    static let questionStem = MathTextStyle(
        fontSize: 18,
        fontWeight: .semibold,
        fontWeightValue: 600,
        lineHeight: 1.6,
        lineSpacing: 5,
        alignment: .leading,
        textAlign: "left",
        textAlignment: .leading
    )

    static let option = MathTextStyle(
        fontSize: 16,
        fontWeight: .medium,
        fontWeightValue: 500,
        lineHeight: 1.45,
        lineSpacing: 2,
        alignment: .leading,
        textAlign: "left",
        textAlignment: .leading
    )

    static let explanation = MathTextStyle(
        fontSize: 16,
        fontWeight: .medium,
        fontWeightValue: 500,
        lineHeight: 1.55,
        lineSpacing: 4,
        alignment: .leading,
        textAlign: "left",
        textAlignment: .leading
    )

    static let body = MathTextStyle(
        fontSize: 16,
        fontWeight: .medium,
        fontWeightValue: 500,
        lineHeight: 1.5,
        lineSpacing: 3,
        alignment: .leading,
        textAlign: "left",
        textAlignment: .leading
    )
}

extension MathTextView {
    static func prewarm() {
        MathWebViewPrewarmer.prewarm()
    }
}

private struct MathWebView: UIViewRepresentable {
    let html: String
    @Binding var height: CGFloat
    @Binding var rendered: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(height: $height, rendered: $rendered)
    }

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "height")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.processPool = MathWebView.processPool

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        webView.isUserInteractionEnabled = false
        webView.navigationDelegate = context.coordinator
        webView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        webView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastHTML != html {
            context.coordinator.lastHTML = html
            if rendered {
                rendered = false
            }
            webView.loadHTMLString(html, baseURL: nil)
        } else {
            context.coordinator.requestHeightUpdate(from: webView)
        }
    }

    fileprivate static let processPool = WKProcessPool()

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private let height: Binding<CGFloat>
        private let rendered: Binding<Bool>
        fileprivate var lastHTML: String?

        init(height: Binding<CGFloat>, rendered: Binding<Bool>) {
            self.height = height
            self.rendered = rendered
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "height" else { return }
            if let number = message.body as? NSNumber {
                updateHeight(CGFloat(truncating: number))
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.rendered.wrappedValue = true
            }
            requestHeightUpdate(from: webView)
        }

        func requestHeightUpdate(from webView: WKWebView) {
            webView.evaluateJavaScript("document.body.scrollHeight") { result, _ in
                if let number = result as? NSNumber {
                    self.updateHeight(CGFloat(truncating: number))
                }
            }
        }

        private func updateHeight(_ newHeight: CGFloat) {
            let resolved = max(1, ceil(newHeight))
            if abs(height.wrappedValue - resolved) > 0.5 {
                DispatchQueue.main.async {
                    self.height.wrappedValue = resolved
                }
            }
        }
    }
}

private enum MathWebViewPrewarmer {
    private static var didPrewarm = false
    private static var warmWebView: WKWebView?

    static func prewarm() {
        guard !didPrewarm else { return }
        didPrewarm = true

        let config = WKWebViewConfiguration()
        config.processPool = MathWebView.processPool
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.isHidden = true
        webView.loadHTMLString(MathHTMLBuilder.prewarmHTML, baseURL: nil)
        warmWebView = webView
    }
}

private enum MathContentDetector {
    static func containsMath(_ text: String) -> Bool {
        return MathTextPreprocessor.requiresMathRendering(text)
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

private enum PlainTextSanitizer {
    static func sanitize(_ text: String) -> String {
        var updated = text
        updated = updated.replacingOccurrences(of: "\\\\", with: "\n")
        updated = updated.replacingOccurrences(of: "\\\"", with: "\"")
        updated = updated.replacingOccurrences(of: "\\'", with: "'")
        updated = updated.replacingOccurrences(of: "\\%", with: "%")
        updated = updated.replacingOccurrences(of: "\\&", with: "&")
        updated = updated.replacingOccurrences(of: "\\_", with: "_")
        updated = updated.replacingOccurrences(of: "\\{", with: "{")
        updated = updated.replacingOccurrences(of: "\\}", with: "}")
        updated = updated.replacingOccurrences(of: "\\\n", with: "\n")
        if let regex = try? NSRegularExpression(pattern: #"\\text\{([^}]*)\}"#, options: []) {
            let range = NSRange(updated.startIndex..<updated.endIndex, in: updated)
            updated = regex.stringByReplacingMatches(in: updated, options: [], range: range, withTemplate: "$1")
        }
        updated = updated.replacingOccurrences(of: "\\", with: "")
        return updated
    }
}

private enum MathAssetLoader {
    private static let katexCSS = loadResource(named: "katex.min", extension: "css")
    private static let katexJS = loadResource(named: "katex.min", extension: "js")
    private static let autoRenderJS = loadResource(named: "auto-render.min", extension: "js")

    static var assetBlockHTML: String {
        if let katexCSS, let katexJS, let autoRenderJS {
            return """
            <style>\(katexCSS)</style>
            <script>\(katexJS)</script>
            <script>\(autoRenderJS)</script>
            """
        }

        return """
        <link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css\">
        <script defer src=\"https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js\"></script>
        <script defer src=\"https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/contrib/auto-render.min.js\"></script>
        """
    }

    private static func loadResource(named name: String, extension ext: String) -> String? {
        let bundle = Bundle.main
        let candidates = [
            bundle.url(forResource: name, withExtension: ext, subdirectory: "Math"),
            bundle.url(forResource: name, withExtension: ext, subdirectory: "Resources/Math"),
            bundle.url(forResource: name, withExtension: ext)
        ]
        for url in candidates.compactMap({ $0 }) {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                return content
            }
        }
        return nil
    }
}

private enum MathHTMLBuilder {
    static func html(for text: String, style: MathTextStyle) -> String {
        let bodyText = buildBody(from: MathTextPreprocessor.preprocess(text))
        let assetBlock = MathAssetLoader.assetBlockHTML
        return """
        <!doctype html>
        <html>
          <head>
            <meta name=\"viewport\" content=\"width=device-width, initial-scale=1, maximum-scale=1\">
            \(assetBlock)
            <style>
              :root { color-scheme: light dark; }
              body {
                margin: 0;
                padding: 0;
                background: transparent;
                font-family: -apple-system, "SF Pro Text", "SF Pro Display", "New York", serif;
                font-size: \(style.fontSize)px;
                font-weight: \(style.fontWeightValue);
                line-height: \(style.lineHeight);
                color: #1A1A1A;
                -webkit-text-size-adjust: 100%;
                -webkit-font-smoothing: antialiased;
              }
              @media (prefers-color-scheme: dark) {
                body { color: #F2EDE6; }
              }
              .content {
                white-space: pre-wrap;
                word-break: break-word;
                overflow-wrap: anywhere;
                text-align: \(style.textAlign);
              }
              .center {
                text-align: center;
                margin: 6px 0;
              }
              .katex { font-size: 1em; }
              .katex-display { margin: 0.35em 0; }
            </style>
          </head>
          <body>
            <div class=\"content\">\(bodyText)</div>
            <script>
              function postHeight() {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.height) {
                  window.webkit.messageHandlers.height.postMessage(document.body.scrollHeight);
                }
              }
              document.addEventListener("DOMContentLoaded", function() {
                renderMathInElement(document.body, {
                  delimiters: [
                    {left: "$$", right: "$$", display: true},
                    {left: "\\\\[", right: "\\\\]", display: true},
                    {left: "$", right: "$", display: false},
                    {left: "\\\\(", right: "\\\\)", display: false}
                  ],
                  throwOnError: false
                });
                postHeight();
                setTimeout(postHeight, 60);
                setTimeout(postHeight, 200);
              });
              window.addEventListener("load", function() {
                postHeight();
                setTimeout(postHeight, 120);
              });
            </script>
          </body>
        </html>
        """
    }

    static var prewarmHTML: String {
        let assetBlock = MathAssetLoader.assetBlockHTML
        return """
        <!doctype html>
        <html>
          <head>
            <meta name=\"viewport\" content=\"width=device-width, initial-scale=1, maximum-scale=1\">
            \(assetBlock)
          </head>
          <body></body>
        </html>
        """
    }

    private static func buildBody(from text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let withMarkers = normalized
            .replacingOccurrences(of: "\\begin{center}", with: "[[CENTER_START]]")
            .replacingOccurrences(of: "\\end{center}", with: "[[CENTER_END]]")

        let escaped = escapeHTML(withMarkers)

        return escaped
            .replacingOccurrences(of: "[[CENTER_START]]", with: "<div class=\"center\">")
            .replacingOccurrences(of: "[[CENTER_END]]", with: "</div>")
    }

    private static func escapeHTML(_ text: String) -> String {
        var escaped = text
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        return escaped
    }
}

private enum MathTextPreprocessor {
    static func requiresMathRendering(_ text: String) -> Bool {
        let markers = ["$", "\\(", "\\[", "\\begin{", "\\frac", "\\sqrt", "\\pi", "\\alpha", "\\beta", "\\gamma", "\\theta"]
        if markers.contains(where: { text.contains($0) }) {
            return true
        }
        return shouldWrapSimpleMath(text)
    }

    static func preprocess(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return text }

        var updated = normalizeMathEnvironments(in: text)
        updated = wrapMathEnvironments(in: updated)
        updated = wrapSimpleMathIfNeeded(updated)
        return updated
    }

    private static func normalizeMathEnvironments(in text: String) -> String {
        var updated = text
        updated = updated.replacingOccurrences(of: "\\begin{align*}", with: "\\begin{aligned}")
        updated = updated.replacingOccurrences(of: "\\end{align*}", with: "\\end{aligned}")
        updated = updated.replacingOccurrences(of: "\\begin{align}", with: "\\begin{aligned}")
        updated = updated.replacingOccurrences(of: "\\end{align}", with: "\\end{aligned}")
        return updated
    }

    private static func wrapMathEnvironments(in text: String) -> String {
        let patterns = [
            #"\\begin\{align\*?\}([\s\S]*?)\\end\{align\*?\}"#,
            #"\\begin\{aligned\}([\s\S]*?)\\end\{aligned\}"#,
            #"\\begin\{equation\*?\}([\s\S]*?)\\end\{equation\*?\}"#
        ]

        var updated = text
        for pattern in patterns {
            updated = wrapEnvironment(pattern: pattern, in: updated)
        }
        return updated
    }

    private static func wrapEnvironment(pattern: String, in text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        guard !matches.isEmpty else { return text }

        var result = text
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            if isWrappedByDisplayMath(result, at: range.lowerBound) {
                continue
            }
            let block = String(result[range])
            result.replaceSubrange(range, with: "$$\(block)$$")
        }
        return result
    }

    private static func isWrappedByDisplayMath(_ text: String, at index: String.Index) -> Bool {
        let prefix = text[..<index].trimmingCharacters(in: .whitespacesAndNewlines)
        return prefix.hasSuffix("$$") || prefix.hasSuffix("\\[")
    }

    private static func wrapSimpleMathIfNeeded(_ text: String) -> String {
        if text.contains("$") || text.contains("\\(") || text.contains("\\[") || text.contains("\\begin{") {
            return text
        }
        if !shouldWrapSimpleMath(text) { return text }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return "$\(trimmed)$"
    }

    private static func shouldWrapSimpleMath(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.count > 80 { return false }

        if containsPlainWords(trimmed) { return false }

        let hasCommand = trimmed.contains("\\") || trimmed.contains("^") || trimmed.contains("_")
        let hasEqualsWithDigits = trimmed.contains("=") && trimmed.range(of: #"\d"#, options: .regularExpression) != nil
        guard hasCommand || hasEqualsWithDigits else { return false }

        let allowed = CharacterSet(charactersIn: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ\\\\^_+-*/=()[]{}., ")
        return trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) })
    }

    private static func containsPlainWords(_ text: String) -> Bool {
        guard let commandRegex = try? NSRegularExpression(pattern: #"\\[A-Za-z]+"#, options: []) else {
            return false
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let strippedCommands = commandRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        let lettersOnly = strippedCommands.replacingOccurrences(of: #"[^A-Za-z ]"#, with: "", options: .regularExpression)
        let words = lettersOnly.split(separator: " ").map { String($0) }
        return words.contains { $0.count >= 2 }
    }
}
