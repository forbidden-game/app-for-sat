import Foundation
import WebKit

enum MathWebViewProcessPool {
    static let shared = WKProcessPool()
}

final class MathWebViewPool: MathWebViewPoolProviding {
    private var pool: [WKWebView] = []
    private let lock = NSLock()
    private let capacity: Int

    init(capacity: Int = 3) {
        self.capacity = max(1, capacity)
    }

    func acquire() -> WKWebView {
        lock.lock()
        defer { lock.unlock() }
        if let webView = pool.popLast() {
            return webView
        }
        return MathWebViewFactory.make()
    }

    func release(_ webView: WKWebView) {
        lock.lock()
        defer { lock.unlock() }
        guard pool.count < capacity else { return }
        pool.append(webView)
    }
}

final class MathWebRenderer: NSObject, MathRenderer, WKNavigationDelegate, WKScriptMessageHandler {
    private enum Message {
        static let rendered = "rendered"
        static let height = "height"
    }

    private var continuation: CheckedContinuation<CGFloat, Error>?
    private weak var webView: WKWebView?
    private var timeoutTask: Task<Void, Never>?
    private let timeoutSeconds: TimeInterval

    init(timeoutSeconds: TimeInterval = 1.2) {
        self.timeoutSeconds = timeoutSeconds
    }

    func render(_ payload: MathHTMLPayload, into webView: WKWebView) async throws -> CGFloat {
        if continuation != nil {
            throw MathRenderFailure.renderFailed("concurrent render not supported")
        }

        let controller = webView.configuration.userContentController
        controller.removeScriptMessageHandler(forName: Message.rendered)
        controller.removeScriptMessageHandler(forName: Message.height)
        controller.add(self, name: Message.rendered)
        controller.add(self, name: Message.height)

        self.webView = webView
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.loadHTMLString(payload.html, baseURL: nil)

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.startTimeout()
        }
    }

    func cancel() {
        timeoutTask?.cancel()
        timeoutTask = nil
        if let continuation {
            self.continuation = nil
            continuation.resume(throwing: MathRenderFailure.renderFailed("render cancelled"))
        }
        cleanupHandlers()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        requestHeight(from: webView)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case Message.height:
            if let number = message.body as? NSNumber {
                completeSuccess(CGFloat(truncating: number))
            }
        case Message.rendered:
            if let webView = webView {
                requestHeight(from: webView)
            }
        default:
            break
        }
    }

    private func requestHeight(from webView: WKWebView) {
        webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, error in
            guard let self else { return }
            if let number = result as? NSNumber {
                self.completeSuccess(CGFloat(truncating: number))
                return
            }
            if let error {
                self.completeFailure(error)
                return
            }
            self.completeFailure(MathRenderFailure.renderFailed("height unavailable"))
        }
    }

    private func startTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
            self.completeFailure(MathRenderFailure.renderFailed("render timeout"))
        }
    }

    private func completeSuccess(_ height: CGFloat) {
        finalize(with: .success(max(1, ceil(height))))
    }

    private func completeFailure(_ error: Error) {
        finalize(with: .failure(error))
    }

    private func finalize(with result: Result<CGFloat, Error>) {
        timeoutTask?.cancel()
        timeoutTask = nil
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
        cleanupHandlers()
    }

    private func cleanupHandlers() {
        guard let webView else { return }
        let controller = webView.configuration.userContentController
        controller.removeScriptMessageHandler(forName: Message.rendered)
        controller.removeScriptMessageHandler(forName: Message.height)
    }
}

private enum MathWebViewFactory {
    static func make() -> WKWebView {
        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()
        config.userContentController = controller
        config.processPool = MathWebViewProcessPool.shared
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        return webView
    }
}
