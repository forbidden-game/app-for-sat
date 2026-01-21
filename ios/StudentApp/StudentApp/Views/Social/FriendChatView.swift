import SwiftUI
import StudentCore

struct FriendChatView: View {
    let friend: FriendThreadSummary
    let userId: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: FriendChatViewModel

    init(friend: FriendThreadSummary, userId: String) {
        self.friend = friend
        self.userId = userId
        _vm = StateObject(wrappedValue: FriendChatViewModel(threadId: friend.threadId))
    }

    var body: some View {
        VStack(spacing: 0) {
            ModalTopBar(
                title: friend.username,
                showsClose: true,
                leadingSystemImage: "chevron.left",
                onClose: { dismiss() }
            )

            ChatTemplateView(
                showHeader: false,
                header: { EmptyView() },
                messages: vm.messages,
                scrollToBottomToken: scrollToken,
                emptyState: {
                    Text("开始聊天")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                },
                row: { message, _, _ in
                    FriendChatBubble(message: message, isUser: message.senderId == userId)
                },
                banner: {
                    if let error = vm.errorMessage, !error.isEmpty {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.statusDanger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                },
                composer: {
                    FriendChatComposer(
                        text: $vm.draftText,
                        isSending: vm.isSending,
                        onSend: { Task { await vm.send() } }
                    )
                }
            )
        }
        .background(AppTheme.backgroundGradient.ignoresSafeArea())
        .task {
            await vm.load()
        }
    }

    private var scrollToken: String {
        guard let last = vm.messages.last else { return "empty" }
        return "\(last.id)|\(last.content.count)"
    }
}

private struct FriendChatBubble: View {
    let message: FriendMessage
    let isUser: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer(minLength: 52)
            }

            Text(message.content)
                .font(.body)
                .foregroundStyle(isUser ? AppTheme.textOnAccent : AppTheme.textPrimary)
                .padding(12)
                .background(isUser ? AppTheme.accentStrong : AppTheme.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isUser ? Color.clear : AppTheme.divider, lineWidth: 1)
                )

            if !isUser {
                Spacer(minLength: 52)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
        .padding(.top, 8)
    }
}

private struct FriendChatComposer: View {
    @Binding var text: String
    let isSending: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("发消息…", text: $text, axis: .vertical)
                .textInputAutocapitalization(.never)
                .foregroundStyle(AppTheme.textPrimary)

            Button(action: onSend) {
                if isSending {
                    ProgressView()
                        .tint(AppTheme.textOnAccent)
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textOnAccent)
                        .frame(width: 32, height: 32)
                }
            }
            .buttonStyle(.plain)
            .disabled(isSending)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .appSurface(fill: AppTheme.surface, stroke: AppTheme.divider, showShadow: false)
    }
}
