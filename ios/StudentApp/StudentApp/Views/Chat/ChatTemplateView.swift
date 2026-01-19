import SwiftUI

struct ChatTemplateView<
    Message: Identifiable,
    Header: View,
    EmptyState: View,
    Row: View,
    Banner: View,
    Composer: View
>: View {
    let showHeader: Bool
    @ViewBuilder let header: () -> Header
    let messages: [Message]
    let scrollToBottomToken: AnyHashable
    @ViewBuilder let emptyState: () -> EmptyState
    @ViewBuilder let row: (Message, Int, @escaping (Message.ID) -> Void) -> Row
    @ViewBuilder let banner: () -> Banner
    @ViewBuilder let composer: () -> Composer

    @State private var isPinnedToBottom = true
    @State private var scrollViewHeight: CGFloat = 0
    @State private var lastMessageCount = 0

    var body: some View {
        VStack(spacing: 12) {
            if showHeader {
                header()
            }

            GeometryReader { proxy in
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if messages.isEmpty {
                                emptyState()
                            }

                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                                row(message, index) { messageId in
                                    scrollToMessage(scrollProxy, messageId: messageId)
                                }
                            }

                            Color.clear
                                .frame(height: 1)
                                .id("BOTTOM")
                                .background(
                                    GeometryReader { geometry in
                                        Color.clear
                                            .preference(
                                                key: BottomAnchorPreferenceKey.self,
                                                value: geometry.frame(in: .named("chatScroll")).maxY
                                            )
                                    }
                                )
                        }
                        .padding(.horizontal, AppMetrics.screenHorizontalPadding)
                        .padding(.top, 4)
                        .padding(.bottom, 12)
                    }
                    .coordinateSpace(name: "chatScroll")
                    .onAppear {
                        scrollViewHeight = proxy.size.height
                        lastMessageCount = messages.count
                    }
                    .onChange(of: proxy.size.height) { _, newValue in
                        scrollViewHeight = newValue
                    }
                    .onChange(of: messages.count) { _, newCount in
                        let wasEmpty = lastMessageCount == 0
                        lastMessageCount = newCount
                        guard isPinnedToBottom else { return }
                        scrollToBottom(scrollProxy, animated: !wasEmpty)
                    }
                    .onChange(of: scrollToBottomToken) { _, _ in
                        guard isPinnedToBottom else { return }
                        scrollToBottom(scrollProxy, animated: false)
                    }
                    .onPreferenceChange(BottomAnchorPreferenceKey.self) { bottomY in
                        let threshold: CGFloat = 120
                        let nearBottom = bottomY <= scrollViewHeight + threshold
                        if nearBottom != isPinnedToBottom {
                            isPinnedToBottom = nearBottom
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if !isPinnedToBottom {
                            Button {
                                scrollToBottom(scrollProxy, animated: true)
                            } label: {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .frame(width: 36, height: 36)
                                    .background(AppTheme.surface)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(AppTheme.divider, lineWidth: 1)
                                    )
                                    .shadow(color: AppTheme.shadowSoft, radius: 6, x: 0, y: 3)
                            }
                            .padding(.trailing, 6)
                            .padding(.bottom, 4)
                        }
                    }
                }
            }

            VStack(spacing: 8) {
                banner()
                composer()
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        let transaction = Transaction(animation: animated ? .easeOut(duration: 0.2) : nil)
        withTransaction(transaction) {
            proxy.scrollTo("BOTTOM", anchor: .bottom)
        }
    }

    private func scrollToMessage(_ proxy: ScrollViewProxy, messageId: Message.ID) {
        let transaction = Transaction(animation: .easeOut(duration: 0.2))
        withTransaction(transaction) {
            proxy.scrollTo(messageId, anchor: .center)
        }
    }
}

private struct BottomAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
