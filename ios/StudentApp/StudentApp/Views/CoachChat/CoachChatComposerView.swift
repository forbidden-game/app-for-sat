import SwiftUI
import UIKit

struct CoachChatComposerView: View {
    @Binding var draftText: String
    let promptText: String
    let isSending: Bool
    let isRecording: Bool
    let recordingStartedAt: Date
    let pendingImage: UIImage?
    let errorMessage: String?
    let onSend: () -> Void
    let onCamera: () -> Void
    let onLibrary: () -> Void
    let onToggleRecording: () -> Void
    let onClearImage: () -> Void

    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.statusDanger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppMetrics.screenHorizontalPadding)
            }

            if let pendingImage {
                pendingImagePreview(pendingImage)
                    .padding(.horizontal, AppMetrics.screenHorizontalPadding)
            }

            if isRecording {
                RecordingBar(startedAt: recordingStartedAt)
                    .padding(.horizontal, AppMetrics.screenHorizontalPadding)
            }

            HStack(spacing: 10) {
                cameraButton
                libraryButton

                TextField(
                    "",
                    text: $draftText,
                    prompt: Text(promptText)
                        .foregroundStyle(AppTheme.textMuted),
                    axis: .vertical
                )
                .font(.body)
                .textInputAutocapitalization(.never)
                .lineLimit(1...4)
                .submitLabel(.send)
                .focused($isInputFocused)
                .onSubmit {
                    onSend()
                }
                .onChange(of: draftText) { _, newValue in
                    guard newValue.last == "\n" else { return }
                    let trimmed = newValue.trimmingCharacters(in: .newlines)
                    draftText = trimmed
                    guard !trimmed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    onSend()
                }
                .padding(.vertical, 11)
                .padding(.horizontal, 12)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.dividerStrong, lineWidth: 1.2)
                )

                if canSend {
                    sendButton
                } else {
                    micButton
                }
            }
            .padding(.horizontal, AppMetrics.screenHorizontalPadding)
        }
    }

    private var canSend: Bool {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty || pendingImage != nil
    }

    private var cameraButton: some View {
        CoachChatIconButton(
            icon: "camera.fill",
            accessibilityLabel: "拍照",
            background: AppTheme.surface,
            foreground: AppTheme.textPrimary,
            stroke: AppTheme.dividerStrong,
            action: onCamera
        )
    }

    private var libraryButton: some View {
        CoachChatIconButton(
            icon: "photo.on.rectangle",
            accessibilityLabel: "相册",
            background: AppTheme.surface,
            foreground: AppTheme.textPrimary,
            stroke: AppTheme.dividerStrong,
            action: onLibrary
        )
    }

    private var micButton: some View {
        CoachChatIconButton(
            icon: isRecording ? "stop.fill" : "mic.fill",
            accessibilityLabel: isRecording ? "停止录音" : "语音输入",
            background: isRecording ? AppTheme.statusDanger : AppTheme.accent,
            foreground: AppTheme.textOnAccent,
            stroke: isRecording ? AppTheme.statusDanger : AppTheme.accentStrong,
            action: onToggleRecording
        )
    }

    private var sendButton: some View {
        Button(action: onSend) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSending ? AppTheme.accentSoft : AppTheme.accentStrong)

                if isSending {
                    ProgressView()
                        .tint(AppTheme.textPrimary)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textOnAccent)
                }
            }
            .frame(width: 44, height: 44)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.accent, lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
        .disabled(isSending)
        .accessibilityLabel("发送")
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
                        .stroke(AppTheme.dividerStrong, lineWidth: 1.2)
                )
                .clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text("已选择图片")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("可以补一句你卡住的步骤")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Button(action: onClearImage) {
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
        .background(AppTheme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.dividerStrong, lineWidth: 1.2)
        )
    }
}

private struct CoachChatIconButton: View {
    let icon: String
    let accessibilityLabel: String
    let background: Color
    let foreground: Color
    let stroke: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: 44, height: 44)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(stroke, lineWidth: 1.2)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
