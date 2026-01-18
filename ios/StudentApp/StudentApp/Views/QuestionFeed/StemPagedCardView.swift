import SwiftUI
import WebKit
import StudentCore

struct StemPagedCardView: View {
    let questionId: String
    let text: String
    @ObservedObject var state: QuestionFeedState

    @State private var pageCount: Int = 1
    @State private var pageIndex: Int = 0
    @State private var didInteract: Bool = false

    var body: some View {
        PagedMathWebView(
            text: text,
            style: .questionStem,
            textColor: AppTheme.textPrimary,
            pageCount: $pageCount,
            pageIndex: $pageIndex,
            onUserInteraction: {
                if !didInteract {
                    didInteract = true
                    state.markSeenStemSwipeHint(for: questionId)
                }
            }
        )
        .onAppear {
            pageIndex = state.stemPage(for: questionId)
        }
        .onChange(of: questionId) { _, newId in
            didInteract = false
            pageCount = 1
            pageIndex = state.stemPage(for: newId)
        }
        .onChange(of: pageIndex) { _, newValue in
            state.setStemPage(newValue, for: questionId)
        }
        .onChange(of: pageCount) { _, newValue in
            guard newValue > 0 else { return }
            let clamped = max(0, min(pageIndex, newValue - 1))
            if clamped != pageIndex {
                pageIndex = clamped
            }
        }
        .overlay(alignment: .bottomLeading) {
            if shouldShowHint {
                swipeHint
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if pageCount > 1 {
                pageIndicator
            }
        }
        .animation(.easeInOut(duration: 0.2), value: shouldShowHint)
    }

    private var shouldShowHint: Bool {
        pageCount > 1 && !didInteract && !state.hasSeenStemSwipeHint(for: questionId)
    }

    private var pageIndicator: some View {
        Text("\(pageIndex + 1)/\(pageCount)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.textOnAccent)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(AppTheme.accentStrong.opacity(0.9))
            .clipShape(Capsule())
            .padding(8)
    }

    private var swipeHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.left.and.right")
                .font(.caption.weight(.semibold))
            Text("Swipe left/right")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(AppTheme.textMuted)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(AppTheme.surface.opacity(0.9))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(AppTheme.divider, lineWidth: 1)
        )
        .padding(8)
    }
}

private struct PagedMathWebView: UIViewRepresentable {
    let text: String
    let style: MathTextStyle
    let textColor: Color
    @Binding var pageCount: Int
    @Binding var pageIndex: Int
    let onUserInteraction: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    func makeCoordinator() -> Coordinator {
        Coordinator(pageCount: $pageCount, pageIndex: $pageIndex, onUserInteraction: onUserInteraction)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.processPool = MathWebViewProcessPool.shared

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.alwaysBounceHorizontal = true
        webView.scrollView.bounces = false
        webView.scrollView.decelerationRate = .fast
        webView.scrollView.isDirectionalLockEnabled = true
        webView.scrollView.delegate = context.coordinator
        webView.scrollView.panGestureRecognizer.delegate = context.coordinator
        webView.navigationDelegate = context.coordinator

        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let resolvedTextColorHex = ColorHexBuilder.hex(for: textColor, scheme: colorScheme)
        let requestKey = [
            style.cacheKey,
            colorScheme == .dark ? "dark" : "light",
            String(format: "%.2f", displayScale),
            resolvedTextColorHex,
            text
        ].joined(separator: "|")

        context.coordinator.updateLayoutIfNeeded(for: webView)

        if context.coordinator.lastKey != requestKey {
            context.coordinator.lastKey = requestKey
            context.coordinator.pendingPageIndex = pageIndex

            let doc = MathMarkupParser().parse(text)
            let html = MathHTMLBuilderV2.pagedHTML(
                for: doc,
                style: style,
                colorScheme: colorScheme,
                displayScale: displayScale,
                textColorHex: resolvedTextColorHex
            )
            webView.loadHTMLString(html, baseURL: MathHTMLBuilderV2.localAssetBaseURL)
            return
        }

        // External state restoration (e.g. returning to a previously viewed question).
        if context.coordinator.lastAppliedPageIndex != pageIndex {
            context.coordinator.scrollToPage(pageIndex, animated: false)
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.scrollView.delegate = nil
        webView.scrollView.panGestureRecognizer.delegate = nil
        webView.navigationDelegate = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        private let pageCount: Binding<Int>
        private let pageIndex: Binding<Int>
        private let onUserInteraction: () -> Void

        weak var webView: WKWebView?
        var lastKey: String = ""
        var pendingPageIndex: Int?
        var lastAppliedPageIndex: Int?
        private var lastViewportSize: CGSize = .zero
        private var didReportUserInteraction = false

        init(pageCount: Binding<Int>, pageIndex: Binding<Int>, onUserInteraction: @escaping () -> Void) {
            self.pageCount = pageCount
            self.pageIndex = pageIndex
            self.onUserInteraction = onUserInteraction
        }

        func updateLayoutIfNeeded(for webView: WKWebView) {
            let size = webView.scrollView.bounds.size
            if size != lastViewportSize {
                lastViewportSize = size
                // Recompute page count + snap after rotation / layout changes.
                DispatchQueue.main.async { [weak self] in
                    self?.updatePageCountAndSyncIndex()
                    if let page = self?.pageIndex.wrappedValue {
                        self?.scrollToPage(page, animated: false)
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Content size may change after KaTeX and/or images load.
            scheduleMetricUpdates()
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let webView, gestureRecognizer == webView.scrollView.panGestureRecognizer else {
                return true
            }
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else {
                return true
            }

            let translation = pan.translation(in: webView)
            let velocity = pan.velocity(in: webView)
            let dx = abs(translation.x) > 0 ? translation.x : velocity.x
            let dy = abs(translation.y) > 0 ? translation.y : velocity.y

            // Only handle horizontal pans here. Vertical pans should bubble up to the outer feed.
            return abs(dx) > abs(dy)
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            if !didReportUserInteraction {
                didReportUserInteraction = true
                onUserInteraction()
            }
        }

        func scrollViewWillEndDragging(
            _ scrollView: UIScrollView,
            withVelocity velocity: CGPoint,
            targetContentOffset: UnsafeMutablePointer<CGPoint>
        ) {
            let pageWidth = max(scrollView.bounds.width, 1)
            let maxIndex = max(pageCount.wrappedValue - 1, 0)
            let target = targetContentOffset.pointee.x / pageWidth

            // Snap to the nearest page.
            let page = Int(round(target))
            let clamped = max(0, min(page, maxIndex))
            targetContentOffset.pointee.x = CGFloat(clamped) * pageWidth
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            syncPageIndex(from: scrollView)
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                syncPageIndex(from: scrollView)
            }
        }

        func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
            syncPageIndex(from: scrollView)
        }

        func scrollToPage(_ page: Int, animated: Bool) {
            guard let webView else { return }
            let pageWidth = max(webView.scrollView.bounds.width, 1)
            let maxIndex = max(pageCount.wrappedValue - 1, 0)
            let clamped = max(0, min(page, maxIndex))
            lastAppliedPageIndex = clamped
            webView.scrollView.setContentOffset(CGPoint(x: CGFloat(clamped) * pageWidth, y: 0), animated: animated)
        }

        private func syncPageIndex(from scrollView: UIScrollView) {
            let pageWidth = max(scrollView.bounds.width, 1)
            let maxIndex = max(pageCount.wrappedValue - 1, 0)
            let page = Int(round(scrollView.contentOffset.x / pageWidth))
            let clamped = max(0, min(page, maxIndex))
            lastAppliedPageIndex = clamped
            if pageIndex.wrappedValue != clamped {
                pageIndex.wrappedValue = clamped
            }
        }

        private func updatePageCountAndSyncIndex() {
            guard let webView else { return }
            let scrollView = webView.scrollView
            let pageWidth = max(scrollView.bounds.width, 1)
            let pages = max(1, Int(ceil(scrollView.contentSize.width / pageWidth)))
            if pageCount.wrappedValue != pages {
                pageCount.wrappedValue = pages
            }

            let maxIndex = max(pages - 1, 0)
            if pageIndex.wrappedValue > maxIndex {
                pageIndex.wrappedValue = maxIndex
            }

            if let pending = pendingPageIndex {
                let maxIndex = max(pages - 1, 0)
                let clamped = max(0, min(pending, maxIndex))
                scrollToPage(clamped, animated: false)
                if pending <= maxIndex {
                    pendingPageIndex = nil
                }
            } else {
                syncPageIndex(from: scrollView)
            }
        }

        private func scheduleMetricUpdates() {
            // Run a few passes to catch reflow after KaTeX + remote images.
            updatePageCountAndSyncIndex()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.updatePageCountAndSyncIndex()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.updatePageCountAndSyncIndex()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                self?.updatePageCountAndSyncIndex()
            }
        }
    }
}
