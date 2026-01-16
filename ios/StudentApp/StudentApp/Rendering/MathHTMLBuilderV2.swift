import Foundation
import SwiftUI

enum MathHTMLBuilderV2 {
    static func html(
        for text: String,
        style: MathTextStyle,
        colorScheme: ColorScheme,
        displayScale: CGFloat
    ) -> String {
        let bodyText = buildBody(from: text)
        let assetBlock = MathAssetLoaderV2.assetBlockHTML
        let textColor = colorScheme == .dark ? "#F2EDE6" : "#1A1A1A"
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
                color: \(textColor);
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
              .center {
                text-align: center;
                margin: 6px 0;
              }
              .katex { font-size: 1em; }
              .katex-display { margin: 0.35em 0; }
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
