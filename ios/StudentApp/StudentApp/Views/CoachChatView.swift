import AVFoundation
import SwiftUI
import UIKit
import StudentCore

struct CoachChatView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var audioPlayer: AVAudioPlayer?
    @State private var audioPlayerDelegate = AudioPlayerDelegate()
    @State private var playingMessageId: String?
    @State private var playbackProgress: Double = 0
    @State private var playbackTimer: Timer?

    @State private var toast: ChatToast?
    @State private var linkedAttemptContextId: String?

    @FocusState private var isInputFocused: Bool

    @StateObject private var vm: CoachChatViewModel

    init(studentId: String, linkedAttemptId: String? = nil, initialDraftText: String? = nil) {
        _linkedAttemptContextId = State(initialValue: linkedAttemptId)
        _vm = StateObject(
            wrappedValue: CoachChatViewModel(
                studentId: studentId,
                initialDraftText: initialDraftText
            )
        )
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            ChatTemplateView(
                header: {
                    CoachChatHeaderView(
                        statusText: assistantStatusText,
                        isStreaming: isAssistantStreaming,
                        hasLinkedAttempt: false,
                        onBack: { dismiss() }
                    )
                },
                messages: vm.messages,
                scrollToBottomToken: scrollToBottomToken,
                emptyState: {
                    CoachChatEmptyStateView()
                        .padding(.top, 12)
                },
                row: { message in
                    CoachChatMessageBubble(
                        message: message,
                        playingMessageId: playingMessageId,
                        playbackProgress: playbackProgress,
                        onPlayAudio: { messageId, payload in
                            togglePlayback(messageId: messageId, payload: payload)
                        }
                    )
                },
                banner: {
                    if linkedAttemptContextId != nil {
                        CoachChatContextBanner(onRemove: removeLinkedAttemptContext)
                            .padding(.horizontal, AppMetrics.screenHorizontalPadding)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                },
                composer: {
                    CoachChatComposerView(
                        draftText: $vm.draftText,
                        placeholder: "发消息…",
                        isSending: vm.isSending,
                        errorMessage: vm.errorMessage,
                        isInputFocused: $isInputFocused,
                        onSend: sendMessage,
                        onCamera: { showToast("即将上线：拍题") },
                        onLibrary: { showToast("即将上线：相册选题") },
                        onMic: { showToast("即将上线：语音") }
                    )
                }
            )
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .overlay(alignment: .bottom) {
            if let toast {
                ChatToastView(text: toast.text)
                    .padding(.horizontal, AppMetrics.screenHorizontalPadding)
                    .padding(.bottom, 96)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task {
            await vm.load()
        }
        .onDisappear {
            stopPlayback()
            Task { await vm.stop() }
        }
    }

    private var assistantStatusText: String {
        isAssistantStreaming ? "思考中" : "在线"
    }

    private var isAssistantStreaming: Bool {
        vm.messages.last(where: { $0.role == .assistant })?.content.status == "streaming"
    }

    private var scrollToBottomToken: String {
        guard let last = vm.messages.last else { return "empty" }
        let status = last.content.status ?? ""
        return "\(last.id)|\(status)|\(last.content.text.count)"
    }

    private func sendMessage() {
        Task {
            await vm.send(linkedAttemptId: linkedAttemptContextId)
        }
    }

    private func removeLinkedAttemptContext() {
        withAnimation(.easeOut(duration: 0.18)) {
            linkedAttemptContextId = nil
        }
        showToast("已移除本题上下文")
    }

    private func showToast(_ text: String) {
        let toast = ChatToast(text: text)
        withAnimation(.easeOut(duration: 0.18)) {
            self.toast = toast
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run {
                guard self.toast?.id == toast.id else { return }
                withAnimation(.easeIn(duration: 0.18)) {
                    self.toast = nil
                }
            }
        }
    }

    private func togglePlayback(messageId: String, payload: CoachChatAudioPayload) {
        if playingMessageId == messageId {
            stopPlayback()
            return
        }

        stopPlayback()

        let url = audioFileURL(fileName: payload.fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            vm.errorMessage = "语音文件不存在。"
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayerDelegate.onFinish = {
                DispatchQueue.main.async {
                    stopPlayback()
                }
            }
            audioPlayer?.delegate = audioPlayerDelegate
            audioPlayer?.play()
            playingMessageId = messageId
            startPlaybackTimer(duration: payload.duration > 0 ? payload.duration : (audioPlayer?.duration ?? 0))
        } catch {
            vm.errorMessage = "语音播放失败，请稍后重试。"
        }
    }

    private func startPlaybackTimer(duration: TimeInterval) {
        playbackTimer?.invalidate()
        playbackProgress = 0
        let total = max(duration, 0.1)
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let player = audioPlayer else {
                stopPlayback()
                return
            }
            playbackProgress = min(player.currentTime / total, 1)
        }
        if let playbackTimer {
            RunLoop.main.add(playbackTimer, forMode: .common)
        }
    }

    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        playingMessageId = nil
        playbackProgress = 0
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func audioFileURL(fileName: String) -> URL {
        let directory = audioDirectoryURL()
        return directory.appendingPathComponent(fileName)
    }

    private func audioDirectoryURL() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent("CoachAudio", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }
}

private struct ChatToast: Identifiable {
    let id = UUID()
    let text: String
}

private struct ChatToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(AppTheme.surfaceRaised)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.divider, lineWidth: 1)
            )
            .shadow(color: AppTheme.shadowSoft, radius: 10, x: 0, y: 4)
    }
}

private struct CoachChatContextBanner: View {
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "link")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("已关联本题错题")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("将随下一条消息发送")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMuted)
            }

            Spacer(minLength: 0)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.surface)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(AppTheme.divider, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("移除本题上下文")
        }
        .padding(12)
        .background(AppTheme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.dividerStrong, lineWidth: 1.2)
        )
        .shadow(color: AppTheme.shadowSoft, radius: 10, x: 0, y: 4)
    }
}

private struct ChatTemplateView<
    Message: Identifiable,
    Header: View,
    EmptyState: View,
    Row: View,
    Banner: View,
    Composer: View
>: View {
    @ViewBuilder let header: () -> Header
    let messages: [Message]
    let scrollToBottomToken: AnyHashable
    @ViewBuilder let emptyState: () -> EmptyState
    @ViewBuilder let row: (Message) -> Row
    @ViewBuilder let banner: () -> Banner
    @ViewBuilder let composer: () -> Composer

    @State private var isPinnedToBottom = true
    @State private var scrollViewHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 12) {
            header()

            GeometryReader { proxy in
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if messages.isEmpty {
                                emptyState()
                            }

                            ForEach(messages) { message in
                                row(message)
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
                    }
                    .onChange(of: proxy.size.height) { _, newValue in
                        scrollViewHeight = newValue
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
}

private struct BottomAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
