import Foundation
import StudentCore
import SwiftUI

enum MathHTMLBuilderV2 {
    static func html(
        for doc: MathMarkupDocument,
        style: MathTextStyle,
        colorScheme: ColorScheme,
        displayScale: CGFloat,
        textColorHex: String
    ) -> String {
        let bodyText = buildBody(from: doc)
        let assetBlock = MathAssetLoaderV2.assetBlockHTML
        return """
        <!doctype html>
        <html>
          <head>
            <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
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
                color: \(textColorHex);
                -webkit-text-size-adjust: 100%;
                -webkit-font-smoothing: antialiased;
                opacity: 0;
                transform: scale(1);
              }
              body.ready { opacity: 1; }
              .content {
                white-space: pre-wrap;
                word-break: break-word;
                overflow-wrap: anywhere;
                text-align: \(style.textAlign);
                visibility: hidden;
              }
              .content.ready { visibility: visible; }
              img {
                max-width: 100%;
                height: auto;
                display: block;
                margin: 8px auto;
              }
              .center {
                text-align: center;
                margin: 6px 0;
              }
              .katex { font-size: 1em; }
              .katex-display { margin: 0.35em 0; }
              a { color: inherit; text-decoration: underline; }
              code {
                font-family: ui-monospace, "SF Mono", SFMono-Regular, Menlo, Monaco, Consolas, monospace;
                font-size: 0.95em;
                background: rgba(0, 0, 0, 0.08);
                padding: 1px 4px;
                border-radius: 4px;
              }
              @media (prefers-color-scheme: dark) {
                code { background: rgba(255, 255, 255, 0.12); }
              }
            </style>
          </head>
          <body data-scale="\(displayScale)">
            <div class="content">\(bodyText)</div>
            <script>
              function postHeight() {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.height) {
                  window.webkit.messageHandlers.height.postMessage(document.body.scrollHeight);
                }
              }
              document.addEventListener("DOMContentLoaded", function() {
                if (typeof renderMathInElement === "function") {
                  renderMathInElement(document.body, {
                    delimiters: [
                      {left: "$$", right: "$$", display: true},
                      {left: "\\\\[", right: "\\\\]", display: true},
                      {left: "$", right: "$", display: false},
                      {left: "\\\\(", right: "\\\\)", display: false}
                    ],
                    throwOnError: false
                  });
                }
                var content = document.querySelector(".content");
                if (content) { content.classList.add("ready"); }
                document.body.classList.add("ready");
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.rendered) {
                  window.webkit.messageHandlers.rendered.postMessage("ready");
                }
                var hasImages = document.images && document.images.length > 0;
                if (!hasImages) {
                  postHeight();
                  setTimeout(postHeight, 60);
                  setTimeout(postHeight, 200);
                }
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

    static func pagedHTML(
        for doc: MathMarkupDocument,
        style: MathTextStyle,
        colorScheme: ColorScheme,
        displayScale: CGFloat,
        textColorHex: String
    ) -> String {
        let bodyText = buildBody(from: doc)
        let assetBlock = MathAssetLoaderV2.assetBlockHTML
        return """
        <!doctype html>
        <html>
          <head>
            <meta name=\"viewport\" content=\"width=device-width, initial-scale=1, maximum-scale=1\">
            \(assetBlock)
            <style>
              :root { color-scheme: light dark; }
              html, body { height: 100%; overflow: hidden; }
              body {
                margin: 0;
                padding: 0;
                background: transparent;
                font-family: -apple-system, \"SF Pro Text\", \"SF Pro Display\", \"New York\", serif;
                font-size: \(style.fontSize)px;
                font-weight: \(style.fontWeightValue);
                line-height: \(style.lineHeight);
                color: \(textColorHex);
                -webkit-text-size-adjust: 100%;
                -webkit-font-smoothing: antialiased;
                transform: scale(1);
              }
              .content {
                height: 100%;
                white-space: pre-wrap;
                word-break: break-word;
                overflow-wrap: anywhere;
                text-align: \(style.textAlign);
                column-width: 100vw;
                column-gap: 0;
                column-fill: auto;
                visibility: visible;
              }
              img {
                max-width: 100%;
                height: auto;
                max-height: 100%;
                object-fit: contain;
                display: block;
                margin: 8px auto;
              }
              .center {
                text-align: center;
                margin: 6px 0;
              }
              .katex { font-size: 1em; }
              .katex-display { margin: 0.35em 0; }
              a { color: inherit; text-decoration: underline; }
              code {
                font-family: ui-monospace, \"SF Mono\", SFMono-Regular, Menlo, Monaco, Consolas, monospace;
                font-size: 0.95em;
                background: rgba(0, 0, 0, 0.08);
                padding: 1px 4px;
                border-radius: 4px;
              }
              @media (prefers-color-scheme: dark) {
                code { background: rgba(255, 255, 255, 0.12); }
              }
            </style>
          </head>
          <body data-scale=\"\(displayScale)\">
            <div class=\"content\">\(bodyText)</div>
            <script>
              document.addEventListener(\"DOMContentLoaded\", function() {
                if (typeof renderMathInElement === \"function\") {
                  renderMathInElement(document.body, {
                    delimiters: [
                      {left: \"$$\", right: \"$$\", display: true},
                      {left: \\\"\\\\[\\\", right: \\\"\\\\]\\\", display: true},
                      {left: \"$\", right: \"$\", display: false},
                      {left: \\\"\\\\(\\\", right: \\\"\\\\)\\\", display: false}
                    ],
                    throwOnError: false
                  });
                }
              });

            </script>
          </body>
        </html>
        """
    }

    static var prewarmHTML: String {
        let assetBlock = MathAssetLoaderV2.assetBlockHTML
        return """
        <!doctype html>
        <html>
          <head>
            <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
            \(assetBlock)
          </head>
          <body></body>
        </html>
        """
    }

    static var localAssetBaseURL: URL? {
        MathAssetLoaderV2.localAssetBaseURL
    }

    private static func buildBody(from doc: MathMarkupDocument) -> String {
        var output = ""
        for segment in doc.segments {
            switch segment {
            case .text(let text):
                output.append(renderTextSegment(text))
            case .inlineMath(let latex):
                output.append("$")
                output.append(escapeHTML(latex))
                output.append("$")
            case .blockMath(let latex):
                output.append("\n$$")
                output.append(escapeHTML(latex))
                output.append("$$\n")
            }
        }

        return output
            .replacingOccurrences(of: "\\begin{center}", with: "<div class=\"center\">")
            .replacingOccurrences(of: "\\end{center}", with: "</div>")
    }

    private static func escapeHTML(_ text: String) -> String {
        var escaped = text
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&#39;")
        return escaped
    }

    private static func renderTextSegment(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let listNormalized = normalizeListMarkers(in: normalized)
        return renderInlineMarkdown(listNormalized)
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

    private static func renderInlineMarkdown(_ text: String) -> String {
        var output = ""
        var index = text.startIndex
        while index < text.endIndex {
            let char = text[index]
            if char == "`" {
                if let closing = text[index...].dropFirst().firstIndex(of: "`") {
                    let content = String(text[text.index(after: index)..<closing])
                    output.append("<code>")
                    output.append(escapeHTML(content))
                    output.append("</code>")
                    index = text.index(after: closing)
                    continue
                }
            }
            if char == "!", text[index...].hasPrefix("![") {
                let altStart = text.index(index, offsetBy: 2)
                if let closingBracket = text[altStart...].firstIndex(of: "]") {
                    let nextIndex = text.index(after: closingBracket)
                    if nextIndex < text.endIndex,
                       text[nextIndex] == "(",
                       let closingParen = text[nextIndex...].firstIndex(of: ")") {
                        let alt = String(text[altStart..<closingBracket])
                        let rawURL = String(text[text.index(after: nextIndex)..<closingParen])
                        let url = rawURL.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? ""
                        if !url.isEmpty {
                            output.append("<img src=\"")
                            output.append(escapeHTML(url))
                            output.append("\" alt=\"")
                            output.append(escapeHTML(alt))
                            output.append("\" loading=\"lazy\" />")
                            index = text.index(after: closingParen)
                            continue
                        }
                    }
                }
            }
            if char == "[" {
                if let closingBracket = text[index...].firstIndex(of: "]") {
                    let nextIndex = text.index(after: closingBracket)
                    if nextIndex < text.endIndex, text[nextIndex] == "(", let closingParen = text[nextIndex...].firstIndex(of: ")") {
                        let label = String(text[text.index(after: index)..<closingBracket])
                        let url = String(text[text.index(after: nextIndex)..<closingParen])
                        output.append("<a href=\"")
                        output.append(escapeHTML(url))
                        output.append("\">")
                        output.append(escapeHTML(label))
                        output.append("</a>")
                        index = text.index(after: closingParen)
                        continue
                    }
                }
            }
            if char == "*", text[index...].hasPrefix("**") {
                let start = text.index(index, offsetBy: 2)
                if let closing = text[start...].range(of: "**")?.lowerBound {
                    let content = String(text[start..<closing])
                    output.append("<strong>")
                    output.append(renderInlineMarkdown(content))
                    output.append("</strong>")
                    index = text.index(closing, offsetBy: 2)
                    continue
                }
            }
            if char == "*" {
                let start = text.index(after: index)
                if let closing = text[start...].firstIndex(of: "*") {
                    let content = String(text[start..<closing])
                    output.append("<em>")
                    output.append(escapeHTML(content))
                    output.append("</em>")
                    index = text.index(after: closing)
                    continue
                }
            }

            output.append(escapeHTML(String(char)))
            index = text.index(after: index)
        }
        return output
    }
}

private enum MathAssetLoaderV2 {
    private static let katexCSS = loadResource(named: "katex.min", extension: "css")
    private static let katexJS = loadResource(named: "katex.min", extension: "js")
    private static let autoRenderJS = loadResource(named: "auto-render.min", extension: "js")
    private static let katexFontBaseURL = "https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/fonts/"
    private static let hasLocalKaTeXFonts: Bool = {
        let bundle = Bundle.main
        let candidates = [
            bundle.url(forResource: "KaTeX_Main-Regular", withExtension: "woff2", subdirectory: "Math/fonts"),
            bundle.url(forResource: "KaTeX_Main-Regular", withExtension: "woff2", subdirectory: "Resources/Math/fonts"),
            bundle.url(forResource: "KaTeX_Main-Regular", withExtension: "woff2", subdirectory: "fonts")
        ]
        return candidates.contains { $0 != nil }
    }()

    static var assetBlockHTML: String {
        if let katexCSS, let katexJS, let autoRenderJS {
            let css = hasLocalKaTeXFonts
                ? katexCSS
                : katexCSS.replacingOccurrences(of: "url(fonts/", with: "url(\(katexFontBaseURL)")
            return """
            <style>\(css)</style>
            <script>\(katexJS)</script>
            <script>\(autoRenderJS)</script>
            """
        }

        return """
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">
        <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"></script>
        <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/contrib/auto-render.min.js"></script>
        """
    }

    static var localAssetBaseURL: URL? {
        guard hasLocalKaTeXFonts else { return nil }
        let bundle = Bundle.main
        let candidates = [
            bundle.url(forResource: "katex.min", withExtension: "css", subdirectory: "Math"),
            bundle.url(forResource: "katex.min", withExtension: "css", subdirectory: "Resources/Math"),
            bundle.url(forResource: "katex.min", withExtension: "css")
        ]
        return candidates.compactMap { $0?.deletingLastPathComponent() }.first
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
