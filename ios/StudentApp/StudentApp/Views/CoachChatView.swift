import AVFoundation
import SwiftUI
import UIKit
import StudentCore

struct CoachChatView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("coach_chat_custom_subtitle") private var customSubtitle: String = "AI辅导老师"
    @State private var showSubtitleEditor = false
    @State private var subtitleDraft: String = ""

    @State private var audioPlayer: AVAudioPlayer?
    @State private var audioPlayerDelegate = AudioPlayerDelegate()
    @State private var playingMessageId: String?
    @State private var playbackProgress: Double = 0
    @State private var playbackTimer: Timer?

    @State private var toast: ChatToast?
    @State private var linkedAttemptContextId: String?
    @State private var replyToMessageId: String?

    @FocusState private var isInputFocused: Bool

    @StateObject private var vm: CoachChatViewModel
    let showsHeader: Bool

    init(
        studentId: String,
        linkedAttemptId: String? = nil,
        initialDraftText: String? = nil,
        showsHeader: Bool = true
    ) {
        _linkedAttemptContextId = State(initialValue: Self.normalizeLinkedAttemptId(linkedAttemptId))
        _vm = StateObject(
            wrappedValue: CoachChatViewModel(
                studentId: studentId,
                initialDraftText: initialDraftText
            )
        )
        self.showsHeader = showsHeader
    }

    private static func normalizeLinkedAttemptId(_ id: String?) -> String? {
        let trimmed = id?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        // Defensive: avoid sending invalid IDs that the edge function will ignore.
        guard UUID(uuidString: trimmed) != nil else { return nil }
        return trimmed
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            ChatTemplateView(
                showHeader: showsHeader,
                header: {
                    CoachChatHeaderView(
                        title: "王校长",
                        subtitle: baseSubtitle,
                        overrideSubtitle: headerOverrideSubtitle,
                        onBack: { dismiss() },
                        onEditSubtitle: openSubtitleEditor
                    )
                },
                messages: vm.messages,
                scrollToBottomToken: scrollToBottomToken,
                emptyState: {
                    CoachChatEmptyStateView()
                        .padding(.top, 12)
                },
                row: { message, index, scrollToMessage in
                    let previous = index > 0 ? vm.messages[index - 1] : nil
                    let next = index + 1 < vm.messages.count ? vm.messages[index + 1] : nil
                    let replyMessage = message.replyToMessageId.flatMap { replyId in
                        vm.messages.first(where: { $0.id == replyId })
                    }

                    CoachChatMessageRow(
                        message: message,
                        previousMessage: previous,
                        nextMessage: next,
                        replyMessage: replyMessage,
                        playingMessageId: playingMessageId,
                        playbackProgress: playbackProgress,
                        onPlayAudio: { messageId, payload in
                            togglePlayback(messageId: messageId, payload: payload)
                        },
                        onReply: { message in
                            setReply(message: message)
                        },
                        onTapReply: { messageId in
                            scrollToMessage(messageId)
                        }
                    )
                },
                banner: {
                    VStack(spacing: 8) {
                        if let replyMessage = replyContextMessage {
                            CoachChatReplyBanner(message: replyMessage, onRemove: removeReplyContext)
                                .padding(.horizontal, AppMetrics.screenHorizontalPadding)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        if linkedAttemptContextId != nil {
                            CoachChatContextBanner(onRemove: removeLinkedAttemptContext)
                                .padding(.horizontal, AppMetrics.screenHorizontalPadding)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
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
            .padding(.top, showsHeader ? 12 : 0)
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
        .sheet(isPresented: $showSubtitleEditor) {
            CoachChatSubtitleEditorSheet(subtitle: $customSubtitle, draft: $subtitleDraft)
        }
        .task {
            await vm.load()
        }
        .onDisappear {
            stopPlayback()
            Task { await vm.stop() }
        }
    }

    private var baseSubtitle: String {
        let trimmed = customSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "AI辅导老师" : trimmed
    }

    private var headerOverrideSubtitle: String? {
        if isInputFocused {
            let preview = typingPreviewText
            if !preview.isEmpty {
                return preview
            }
        }

        if isAssistantStreaming {
            return "思考中…"
        }

        return nil
    }

    private var typingPreviewText: String {
        let trimmed = vm.draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let normalized = trimmed.replacingOccurrences(of: "\n", with: " ")
        let maxChars = 18
        if normalized.count <= maxChars {
            return normalized
        }
        return String(normalized.prefix(maxChars)) + "…"
    }

    private var isAssistantStreaming: Bool {
        vm.messages.last(where: { $0.role == .assistant })?.content.status == "streaming"
    }

    private var scrollToBottomToken: String {
        guard let last = vm.messages.last else { return "empty" }
        let status = last.content.status ?? ""
        return "\(last.id)|\(status)|\(last.content.text.count)"
    }

    private var replyContextMessage: CoachThreadMessage? {
        guard let replyToMessageId else { return nil }
        return vm.messages.first(where: { $0.id == replyToMessageId })
    }

    private func openSubtitleEditor() {
        subtitleDraft = customSubtitle
        showSubtitleEditor = true
    }

    private func sendMessage() {
        // Capture @State on the main actor before entering an async Task.
        // Otherwise the value can be read off-main (argument evaluation happens before the @MainActor hop).
        let linkedAttemptId = linkedAttemptContextId
        let replyTargetId = replyToMessageId

        Task { @MainActor in
            let didSend = await vm.send(linkedAttemptId: linkedAttemptId, replyToMessageId: replyTargetId)
            if didSend, linkedAttemptId != nil {
                withAnimation(.easeOut(duration: 0.18)) {
                    linkedAttemptContextId = nil
                }
            }
            if didSend, replyTargetId != nil {
                withAnimation(.easeOut(duration: 0.18)) {
                    replyToMessageId = nil
                }
            }
        }
    }

    private func setReply(message: CoachThreadMessage) {
        withAnimation(.easeOut(duration: 0.18)) {
            replyToMessageId = message.id
        }
        isInputFocused = true
    }

    private func removeReplyContext() {
        withAnimation(.easeOut(duration: 0.18)) {
            replyToMessageId = nil
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
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)
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

private struct CoachChatReplyBanner: View {
    let message: CoachThreadMessage
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "quote.bubble")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("引用 \(message.replyAuthorLabel)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(message.replyPreviewText)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMuted)
                    .lineLimit(2)
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
            .accessibilityLabel("取消引用")
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

private struct CoachChatSubtitleEditorSheet: View {
    @Binding var subtitle: String
    @Binding var draft: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 12) {
                    Text("这行会显示在标题下方。输入时会临时显示你正在输入的内容。")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textMuted)

                    TextField("副标题", text: $draft)
                        .textInputAutocapitalization(.never)
                        .padding(.vertical, 11)
                        .padding(.horizontal, 12)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(AppTheme.dividerStrong, lineWidth: 1.2)
                        )
                        .onChange(of: draft) { _, newValue in
                            let maxChars = 24
                            if newValue.count > maxChars {
                                draft = String(newValue.prefix(maxChars))
                            }
                        }

                    Button {
                        draft = ""
                    } label: {
                        Text("恢复默认")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(AppTheme.surfaceRaised)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AppTheme.divider, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, AppMetrics.screenHorizontalPadding)
                .padding(.top, 16)
            }
            .navigationTitle("副标题")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        subtitle = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Defensive: if sheet is opened via system gesture, keep draft in sync.
                if draft.isEmpty {
                    draft = subtitle
                }
            }
        }
        .presentationDetents([.medium])
    }
}

