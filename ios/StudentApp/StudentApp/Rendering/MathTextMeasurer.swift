import Foundation
import SwiftUI
import UIKit
import WebKit

@MainActor
final class MathTextMeasurer {
    static let shared = MathTextMeasurer()

    private let renderer = MathWebRenderer(timeoutSeconds: 3.0)
    private let pool = MathWebViewPool(capacity: 1)
    private var webView: WKWebView?
    private var cache: [String: CGFloat] = [:]

    private static let planner: MathRenderPlanner = {
        let native = AppConfig.swiftMathEnabled ? SwiftMathRenderer() : nil
        return MathRenderPlanner(nativeRenderer: native)
    }()

    private init() {}

    func measure(
        text: String,
        style: MathTextStyle,
        width: CGFloat,
        colorScheme: ColorScheme,
        displayScale: CGFloat,
        textColorHex: String
    ) async -> CGFloat {
        let width = max(1, width)
        let request = MathRenderRequest(
            text: text,
            style: style,
            width: width,
            colorScheme: colorScheme,
            displayScale: displayScale,
            textColorHex: textColorHex
        )
        let key = MathRenderKeyBuilder.key(for: request) + "|measure"
        if let cached = cache[key] {
            return cached
        }

        let plan = Self.planner.plan(for: request)

        let height: CGFloat
        switch plan {
        case .plainText(let attributed):
            height = measurePlainText(String(attributed.characters), style: style, width: width)
        case .nativeLabel(let payload):
            height = measurePlainText(payload.plainText, style: style, width: width)
        case .webHTML(let payload):
            let webView = ensureWebView(width: width)
            do {
                height = try await renderer.render(payload, into: webView)
            } catch {
                height = measurePlainText(payload.accessibilityText, style: style, width: width)
            }
        }

        let finalHeight = max(1, ceil(height))
        cache[key] = finalHeight
        return finalHeight
    }

    private func ensureWebView(width: CGFloat) -> WKWebView {
        if let webView {
            webView.frame = CGRect(x: 0, y: 0, width: width, height: 1)
            return webView
        }
        let webView = pool.acquire()
        webView.frame = CGRect(x: 0, y: 0, width: width, height: 1)
        self.webView = webView
        return webView
    }

    private func measurePlainText(_ text: String, style: MathTextStyle, width: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: style.fontSize, weight: uiFontWeight(for: style.fontWeight))
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = style.lineSpacing
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraph
        ]
        let bounding = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        let lineHeight = style.fontSize * style.lineHeight
        return max(lineHeight, ceil(bounding.height))
    }

    private func uiFontWeight(for weight: Font.Weight) -> UIFont.Weight {
        switch weight {
        case .ultraLight:
            return .ultraLight
        case .thin:
            return .thin
        case .light:
            return .light
        case .medium:
            return .medium
        case .semibold:
            return .semibold
        case .bold:
            return .bold
        case .heavy:
            return .heavy
        case .black:
            return .black
        default:
            return .regular
        }
    }

}
