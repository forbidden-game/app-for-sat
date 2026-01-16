import AVFoundation
import SwiftUI
import UIKit
import StudentCore

struct CoachChatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pendingImage: UIImage?
    @State private var showCameraPicker = false
    @State private var showLibraryPicker = false
    @State private var isRecording = false
    @State private var recordingStartedAt = Date()
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var audioPlayerDelegate = AudioPlayerDelegate()
    @State private var playingMessageId: String?
    @State private var playbackProgress: Double = 0
    @State private var playbackTimer: Timer?
    @State private var recordingFileURL: URL?
    @State private var isPinnedToBottom = true
    @State private var scrollViewHeight: CGFloat = 0

    @StateObject private var vm: CoachChatViewModel
    private let linkedAttemptId: String?

    init(studentId: String, linkedAttemptId: String? = nil, initialDraftText: String? = nil) {
        self.linkedAttemptId = linkedAttemptId
        _vm = StateObject(
            wrappedValue: CoachChatViewModel(
                studentId: studentId,
                linkedAttemptId: linkedAttemptId,
                initialDraftText: initialDraftText
            )
        )
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 12) {
                CoachChatHeaderView(
                    statusText: assistantStatusText,
                    isStreaming: isAssistantStreaming,
                    hasLinkedAttempt: linkedAttemptId != nil,
                    onBack: { dismiss() }
                )

                GeometryReader { proxy in
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                if vm.messages.isEmpty {
                                    CoachChatEmptyStateView(
                                        prompts: Array(vm.promptCandidates.prefix(3)),
                                        onPromptTap: { prompt in
                                            Task { await vm.sendPrompt(prompt) }
                                        },
                                        onCameraTap: openCamera,
                                        onMicTap: toggleRecording
                                    )
                                    .padding(.top, 12)
                                }

                                ForEach(vm.messages) { message in
                                    CoachChatMessageBubble(
                                        message: message,
                                        playingMessageId: playingMessageId,
                                        playbackProgress: playbackProgress,
                                        onPlayAudio: { messageId, payload in
                                            togglePlayback(messageId: messageId, payload: payload)
                                        }
                                    )
                                    .id(message.id)
                                }

                                Color.clear
                                    .frame(height: 1)
                                    .background(
                                        GeometryReader { geometry in
                                            Color.clear
                                                .preference(
                                                    key: BottomAnchorPreferenceKey.self,
                                                    value: geometry.frame(in: .named("coachChatScroll")).maxY
                                                )
                                        }
                                    )
                            }
                            .padding(.horizontal, AppMetrics.screenHorizontalPadding)
                            .padding(.top, 4)
                            .padding(.bottom, 12)
                        }
                        .coordinateSpace(name: "coachChatScroll")
                        .onAppear {
                            scrollViewHeight = proxy.size.height
                        }
                        .onChange(of: proxy.size.height) { _, newValue in
                            scrollViewHeight = newValue
                        }
                        .onChange(of: vm.messages) { _, _ in
                            guard isPinnedToBottom else { return }
                            scrollToBottom(scrollProxy)
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
                                    scrollToBottom(scrollProxy)
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

                CoachChatComposerView(
                    draftText: $vm.draftText,
                    promptText: vm.promptText,
                    isSending: vm.isSending,
                    isRecording: isRecording,
                    recordingStartedAt: recordingStartedAt,
                    pendingImage: pendingImage,
                    errorMessage: vm.errorMessage,
                    onSend: { Task { await vm.send() } },
                    onCamera: openCamera,
                    onLibrary: openLibrary,
                    onToggleRecording: toggleRecording,
                    onClearImage: { pendingImage = nil }
                )
            }
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .sheet(isPresented: $showCameraPicker) {
            ImagePicker(image: $pendingImage, sourceType: .camera)
        }
        .sheet(isPresented: $showLibraryPicker) {
            ImagePicker(image: $pendingImage, sourceType: .photoLibrary)
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

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let last = vm.messages.last else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    private func openCamera() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            showCameraPicker = true
        } else {
            showLibraryPicker = true
        }
    }

    private func openLibrary() {
        showLibraryPicker = true
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                startRecordingSession()
            case .denied:
                vm.errorMessage = "需要麦克风权限才能录音。"
            case .undetermined:
                AVAudioApplication.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        if granted {
                            startRecordingSession()
                        } else {
                            vm.errorMessage = "需要麦克风权限才能录音。"
                        }
                    }
                }
            @unknown default:
                vm.errorMessage = "麦克风权限异常，请稍后重试。"
            }
        } else {
            let session = AVAudioSession.sharedInstance()
            switch session.recordPermission {
            case .granted:
                startRecordingSession()
            case .denied:
                vm.errorMessage = "需要麦克风权限才能录音。"
            case .undetermined:
                session.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        if granted {
                            startRecordingSession()
                        } else {
                            vm.errorMessage = "需要麦克风权限才能录音。"
                        }
                    }
                }
            @unknown default:
                vm.errorMessage = "麦克风权限异常，请稍后重试。"
            }
        }
    }

    private func startRecordingSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let fileName = "coach-audio-\(UUID().uuidString).m4a"
            let url = audioFileURL(fileName: fileName)
            recordingFileURL = url
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.prepareToRecord()
            guard audioRecorder?.record() == true else {
                throw NSError(domain: "CoachChatView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Record failed"])
            }

            recordingStartedAt = Date()
            withAnimation(.easeInOut(duration: 0.2)) {
                isRecording = true
            }
        } catch {
            vm.errorMessage = "录音启动失败，请稍后重试。"
            audioRecorder = nil
            isRecording = false
        }
    }

    private func stopRecording() {
        guard let recorder = audioRecorder else {
            isRecording = false
            return
        }

        recorder.stop()
        let duration = max(recorder.currentTime, Date().timeIntervalSince(recordingStartedAt))
        let url = recordingFileURL ?? recorder.url
        audioRecorder = nil
        recordingFileURL = nil

        withAnimation(.easeInOut(duration: 0.2)) {
            isRecording = false
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
        if duration >= 0.1, fileSize > 0 {
            vm.addLocalAudioMessage(fileName: url.lastPathComponent, duration: duration)
        } else {
            vm.errorMessage = "录音时间太短或保存失败。"
        }

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            return
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

private struct BottomAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
