import SwiftUI

struct CoachChatComposerView: View {
    @Binding var draftText: String

    let placeholder: String
    let isSending: Bool
    let errorMessage: String?

    let isInputFocused: FocusState<Bool>.Binding

    let onSend: () -> Void
    let onCamera: () -> Void
    let onLibrary: () -> Void
    let onMic: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.statusDanger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppMetrics.screenHorizontalPadding)
            }

            HStack(spacing: 10) {
                actionButton(icon: "camera.fill", label: "拍题", action: onCamera)
                actionButton(icon: "photo.on.rectangle", label: "相册", action: onLibrary)
                actionButton(icon: "mic.fill", label: "语音", action: onMic)

                TextField(
                    "",
                    text: $draftText,
                    prompt: Text(placeholder)
                        .foregroundStyle(AppTheme.textMuted),
                    axis: .vertical
                )
                .font(.body)
                .textInputAutocapitalization(.never)
                .lineLimit(1...4)
                .submitLabel(.send)
                .focused(isInputFocused)
                .onSubmit {
                    guard canSend else { return }
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

                sendButton
            }
            .padding(.horizontal, AppMetrics.screenHorizontalPadding)
        }
    }

    private var canSend: Bool {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !isSending
    }

    private var sendButton: some View {
        Button(action: onSend) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(canSend ? AppTheme.accentStrong : AppTheme.surface)

                if isSending {
                    ProgressView()
                        .tint(AppTheme.textPrimary)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(canSend ? AppTheme.textOnAccent : AppTheme.textMuted)
                }
            }
            .frame(width: 44, height: 44)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(canSend ? AppTheme.accent : AppTheme.dividerStrong, lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .accessibilityLabel("发送")
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)
                .frame(width: 44, height: 44)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.dividerStrong, lineWidth: 1.2)
                )
                .opacity(0.65)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
