import SwiftUI

struct ScrollBoundaryScrollView<Content: View>: View {
    let isActive: Bool
    let isScrollEnabled: Bool
    let scrollResetID: String
    @Binding var canPageUp: Bool
    @Binding var canPageDown: Bool
    let content: Content

    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var offsetY: CGFloat = 0
    @State private var lastResetID: String = ""

    private let topAnchorID = "scroll-top-anchor"

    init(
        isActive: Bool,
        isScrollEnabled: Bool,
        scrollResetID: String,
        canPageUp: Binding<Bool>,
        canPageDown: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.isActive = isActive
        self.isScrollEnabled = isScrollEnabled
        self.scrollResetID = scrollResetID
        self._canPageUp = canPageUp
        self._canPageDown = canPageDown
        self.content = content()
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 0)
                        .id(topAnchorID)
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: ScrollOffsetKey.self,
                                    value: proxy.frame(in: .named("scroll")).minY
                                )
                            }
                        )

                    content
                }
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: ContentHeightKey.self, value: proxy.size.height)
                    }
                )
            }
            .coordinateSpace(name: "scroll")
            .scrollIndicators(.hidden)
            .scrollDisabled(!isScrollEnabled)
            .allowsHitTesting(isScrollEnabled)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: ViewportHeightKey.self, value: proxy.size.height)
                }
            )
            .onPreferenceChange(ScrollOffsetKey.self) { offset in
                offsetY = offset
                updatePagingState()
            }
            .onPreferenceChange(ContentHeightKey.self) { height in
                contentHeight = height
                updatePagingState()
            }
            .onPreferenceChange(ViewportHeightKey.self) { height in
                viewportHeight = height
                updatePagingState()
            }
            .onChange(of: isActive) { _, active in
                if active {
                    resetIfNeeded(proxy)
                } else {
                    canPageUp = true
                    canPageDown = true
                }
            }
            .onChange(of: scrollResetID) { _, _ in
                resetIfNeeded(proxy)
            }
        }
    }

    private func updatePagingState() {
        guard isActive else { return }
        let maxScroll = max(contentHeight - viewportHeight, 0)
        let topThreshold: CGFloat = 2
        let bottomThreshold: CGFloat = 2
        let atTop = offsetY >= -topThreshold
        let atBottom = maxScroll <= 0 || offsetY <= -(maxScroll + bottomThreshold)
        canPageUp = atTop
        canPageDown = atBottom
    }

    private func resetIfNeeded(_ proxy: ScrollViewProxy) {
        guard isActive else { return }
        guard scrollResetID != lastResetID else { return }
        lastResetID = scrollResetID
        DispatchQueue.main.async {
            withAnimation(.none) {
                proxy.scrollTo(topAnchorID, anchor: .top)
            }
        }
    }
}

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ViewportHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
