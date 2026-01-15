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

    @StateObject private var vm: CoachChatViewModel

    init(studentId: String, linkedAttemptId: String? = nil, initialDraftText: String? = nil) {
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
                header

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(vm.messages) { msg in
                                messageBubble(msg)
                                    .id(msg.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                    }
                    .onChange(of: vm.messages.count) { _, _ in
                        if let last = vm.messages.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                composer
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
            Task { await vm.stop() }
        }
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppTheme.divider, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 8) {
                CoachAvatarView(size: 28)
                Text("王校长")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Spacer()

            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
    }

    private func messageBubble(_ msg: CoachThreadMessage) -> some View {
        let isUser = msg.role == .user
        let bg = isUser ? AppTheme.accentStrong : AppTheme.surface
        let fg = isUser ? AppTheme.textOnAccent : AppTheme.textPrimary
        let stroke = isUser ? AppTheme.accentStrong : AppTheme.divider
        let audioPayload = CoachChatAudioPayload.parse(from: msg.content.text)

        return HStack(alignment: .top, spacing: 10) {
            if isUser { Spacer(minLength: 40) }

            if !isUser {
                CoachAvatarView(size: 24)
                    .padding(.top, 2)
            }

            VStack(alignment: .leading, spacing: 6) {
                if let audioPayload {
                    AudioMessageBubble(
                        payload: audioPayload,
                        isUser: isUser,
                        foreground: fg,
                        isPlaying: playingMessageId == msg.id,
                        onPlay: { togglePlayback(messageId: msg.id, payload: audioPayload) }
                    )
                } else {
                    Text(msg.content.text)
                        .font(.body)
                        .foregroundStyle(fg)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if msg.role == .assistant, msg.content.status == "streaming" {
                    Text("…")
                        .font(.footnote)
                        .foregroundStyle(fg.opacity(0.8))
                }
            }
            .padding(12)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )

            if !isUser { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if let error = vm.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.statusDanger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
            }

            if let pendingImage {
                pendingImagePreview(pendingImage)
                    .padding(.horizontal, 16)
            }

            if isRecording {
                RecordingBar(startedAt: recordingStartedAt)
                    .padding(.horizontal, 16)
            }

            HStack(spacing: 10) {
                cameraButton

                TextField(
                    "",
                    text: $vm.draftText,
                    prompt: Text(vm.promptText)
                        .foregroundStyle(AppTheme.textSecondary),
                    axis: .vertical
                )
                    .textInputAutocapitalization(.never)
                    .lineLimit(1...4)
                    .submitLabel(.send)
                    .onSubmit {
                        Task { await vm.send() }
                    }
                    .onChange(of: vm.draftText) { _, newValue in
                        guard newValue.last == "\n" else { return }
                        let trimmed = newValue.trimmingCharacters(in: .newlines)
                        vm.draftText = trimmed
                        guard !trimmed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        Task { await vm.send() }
                    }
                    .padding(.vertical, 11)
                    .padding(.horizontal, 12)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.divider, lineWidth: 1.5)
                    )

                micButton
            }
            .padding(.horizontal, 16)
        }
    }

    private var cameraButton: some View {
        let tap = TapGesture().onEnded {
            openCamera()
        }
        let longPress = LongPressGesture(minimumDuration: 0.45).onEnded { _ in
            openLibrary()
        }

        return Image(systemName: "camera")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(AppTheme.textPrimary)
            .frame(width: 44, height: 44)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.divider, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .gesture(longPress.exclusively(before: tap))
            .accessibilityLabel("拍照或相册")
            .accessibilityAddTraits(.isButton)
    }

    private var micButton: some View {
        Button {
            toggleRecording()
        } label: {
            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.textOnAccent)
                .frame(width: 44, height: 44)
                .background(isRecording ? AppTheme.statusDanger : AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isRecording ? AppTheme.statusDanger : AppTheme.accentStrong, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRecording ? "停止录音" : "语音输入")
    }

    private func pendingImagePreview(_ image: UIImage) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 86, height: 86)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.divider, lineWidth: 1.5)
                )
                .clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text("已选择图片")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("可继续输入问题")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Button {
                pendingImage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.surface)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(AppTheme.divider, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.divider, lineWidth: 1.5)
        )
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
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()

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
        let duration = recorder.currentTime
        let url = recorder.url
        audioRecorder = nil

        withAnimation(.easeInOut(duration: 0.2)) {
            isRecording = false
        }

        if duration > 0.3 {
            vm.addLocalAudioMessage(fileName: url.lastPathComponent, duration: duration)
        }

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            return
        }
    }

    private func togglePlayback(messageId: String, payload: CoachChatAudioPayload) {
        if playingMessageId == messageId {
            audioPlayer?.stop()
            audioPlayer = nil
            playingMessageId = nil
            return
        }

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
                    playingMessageId = nil
                    audioPlayer = nil
                }
            }
            audioPlayer?.delegate = audioPlayerDelegate
            audioPlayer?.play()
            playingMessageId = messageId
        } catch {
            vm.errorMessage = "语音播放失败，请稍后重试。"
        }
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

private struct RecordingBar: View {
    let startedAt: Date

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(AppTheme.statusDanger)
                .frame(width: 8, height: 8)

            Text("录音中 \(elapsedText)")
                .font(.footnote)
                .foregroundStyle(AppTheme.textSecondary)

            Spacer()

            RecordingWave()
                .frame(width: 88, height: 16)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.divider, lineWidth: 1.5)
        )
    }

    private var elapsedText: String {
        let seconds = max(0, Int(Date().timeIntervalSince(startedAt)))
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%02d:%02d", minutes, remainder)
    }
}

private struct RecordingWave: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<8, id: \.self) { index in
                    let phase = time * 2.2 + Double(index) * 0.6
                    let height = 4 + abs(sin(phase)) * 10
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.accent)
                        .frame(width: 2, height: height)
                }
            }
        }
    }
}

private struct AudioMessageBubble: View {
    let payload: CoachChatAudioPayload
    let isUser: Bool
    let foreground: Color
    let isPlaying: Bool
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 8) {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 12, weight: .bold))

                Text(durationText)
                    .font(.footnote.weight(.semibold))

                AudioMiniWave(color: foreground.opacity(0.7))
            }
            .foregroundStyle(foreground)
        }
        .buttonStyle(.plain)
    }

    private var durationText: String {
        let totalSeconds = max(0, Int(payload.duration.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct AudioMiniWave: View {
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<6, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color)
                    .frame(width: 2, height: 4 + CGFloat(index % 3) * 2)
            }
        }
    }
}

private final class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    var onFinish: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
    }
}
