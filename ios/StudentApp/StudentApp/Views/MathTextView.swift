import SwiftUI
import WebKit

struct MathTextView: View {
    let text: String
    var style: MathTextStyle = .body

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    @State private var measuredHeight: CGFloat = 1
    @State private var isRendered = false
    @State private var renderFailed = false
    @State private var lastKey: String = ""
    @State private var width: CGFloat = 0
    @State private var plan: MathRenderPlan = .plainText(AttributedString(""))
    @State private var fallbackText: String = ""

    private static let planner: MathRenderPlanner = {
        let native = AppConfig.swiftMathEnabled ? SwiftMathRenderer() : nil
        return MathRenderPlanner(nativeRenderer: native)
    }()
    private static let webPool = MathWebViewPool()

    init(text: String, style: MathTextStyle = .body) {
        self.text = text
        self.style = style
    }

    var body: some View {
        let request = MathRenderRequest(
            text: text,
            style: style,
            width: max(width, 1),
            colorScheme: colorScheme,
            displayScale: displayScale
        )
        let requestKey = MathRenderKeyBuilder.key(for: request)
        let activePlan = renderFailed ? MathRenderPlan.plainText(AttributedString(fallbackText)) : plan

        ZStack(alignment: .topLeading) {
            if case .webHTML = activePlan {
                Color.clear
                    .frame(height: max(1, measuredHeight))
            }

            content(for: activePlan, requestKey: requestKey)
        }
        .frame(maxWidth: .infinity, alignment: style.alignment)
        .background(WidthReader())
        .onPreferenceChange(WidthKey.self) { newWidth in
            if abs(width - newWidth) > 0.5 {
                width = newWidth
            }
        }
        .onAppear {
            updatePlan(request: request, key: requestKey)
        }
        .onChange(of: requestKey) { _, newKey in
            updatePlan(request: request, key: newKey)
        }
    }

    private func content(for plan: MathRenderPlan, requestKey: String) -> some View {
        switch plan {
        case .plainText(let text):
            return AnyView(
                Text(text)
                    .font(.system(size: style.fontSize, weight: style.fontWeight))
                    .lineSpacing(style.lineSpacing)
                    .multilineTextAlignment(style.textAlignment)
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: style.alignment)
            )
        case .nativeLabel(let payload):
            return AnyView(
                SwiftMathLabelView(payload: payload)
                    .frame(maxWidth: .infinity, alignment: style.alignment)
                    .accessibilityLabel(Text(payload.plainText))
            )
        case .webHTML(let payload):
            return AnyView(
                MathWebContainer(
                    payload: payload,
                    requestKey: requestKey,
                    pool: Self.webPool,
                    measuredHeight: $measuredHeight,
                    isRendered: $isRendered,
                    onFailure: {
                        renderFailed = true
                    }
                )
                .frame(height: max(1, measuredHeight))
                .frame(maxWidth: .infinity, alignment: style.alignment)
                .opacity(isRendered ? 1 : 0)
                .accessibilityLabel(Text(payload.accessibilityText))
            )
        }
    }

    private func updatePlan(request: MathRenderRequest, key: String) {
        guard key != lastKey else { return }
        lastKey = key
        renderFailed = false
        isRendered = false

        let plan = Self.planner.plan(for: request)
        self.plan = plan

        switch plan {
        case .plainText:
            fallbackText = text
        case .nativeLabel(let payload):
            fallbackText = payload.plainText
        case .webHTML(let payload):
            fallbackText = payload.accessibilityText
            measuredHeight = max(1, payload.estimatedHeight)
        }
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

    var cacheKey: String {
        "\(fontSize)|\(fontWeightValue)|\(lineHeight)|\(lineSpacing)|\(textAlign)"
    }
}

extension MathTextView {
    static func prewarm() {
        MathWebViewPrewarmer.prewarm()
    }
}

private struct MathWebContainer: UIViewRepresentable {
    let payload: MathHTMLPayload
    let requestKey: String
    let pool: MathWebViewPoolProviding
    @Binding var measuredHeight: CGFloat
    @Binding var isRendered: Bool
    let onFailure: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(pool: pool)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = context.coordinator.webView
        webView.isHidden = true
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastKey != requestKey else { return }
        context.coordinator.lastKey = requestKey
        isRendered = false
        webView.isHidden = true
        measuredHeight = max(1, payload.estimatedHeight)

        context.coordinator.renderTask?.cancel()
        context.coordinator.renderer.cancel()
        context.coordinator.renderTask = Task {
            do {
                let height = try await context.coordinator.renderer.render(payload, into: webView)
                await MainActor.run {
                    measuredHeight = height
                    isRendered = true
                    webView.isHidden = false
                }
            } catch {
                await MainActor.run {
                    isRendered = false
                    onFailure()
                }
            }
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.renderTask?.cancel()
        coordinator.renderTask = nil
        coordinator.renderer.cancel()
        coordinator.pool.release(webView)
    }

    final class Coordinator {
        let pool: MathWebViewPoolProviding
        let renderer: MathWebRenderer
        let webView: WKWebView
        var renderTask: Task<Void, Never>?
        var lastKey: String = ""

        init(pool: MathWebViewPoolProviding) {
            self.pool = pool
            self.renderer = MathWebRenderer()
            self.webView = pool.acquire()
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
        config.processPool = MathWebViewProcessPool.shared
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.isHidden = true
        webView.loadHTMLString(MathHTMLBuilderV2.prewarmHTML, baseURL: nil)
        warmWebView = webView
    }
}

private struct WidthReader: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: WidthKey.self, value: proxy.size.width)
        }
    }
}

private struct WidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
