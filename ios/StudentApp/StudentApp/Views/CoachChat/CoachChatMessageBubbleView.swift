import SwiftUI
import StudentCore

struct CoachChatMessageBubble: View {
    let message: CoachThreadMessage
    let playingMessageId: String?
    let playbackProgress: Double
    let onPlayAudio: (String, CoachChatAudioPayload) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        let audioPayload = CoachChatAudioPayload.parse(from: message.content.text)
        let foreground = isUser ? AppTheme.textOnAccent : AppTheme.textPrimary
        let bubbleBackground = isUser ? AppTheme.accentStrong : AppTheme.surfaceRaised
        let bubbleStroke = isUser ? AppTheme.accentStrong : AppTheme.dividerStrong

        return HStack(alignment: .top, spacing: 10) {
            if isUser { Spacer(minLength: 40) }

            if !isUser {
                CoachAvatarView(size: 26)
                    .padding(.top, 2)
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 6) {
                    if let audioPayload {
                        AudioMessageBubble(
                            payload: audioPayload,
                            isUser: isUser,
                            foreground: foreground,
                            isPlaying: playingMessageId == message.id,
                            progress: playingMessageId == message.id ? playbackProgress : 0,
                            onPlay: { onPlayAudio(message.id, audioPayload) }
                        )
                    } else {
                        Text(message.content.text)
                            .font(.body)
                            .foregroundStyle(foreground)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if message.role == .assistant, message.content.status == "streaming" {
                        CoachChatTypingIndicator(reduceMotion: reduceMotion)
                    }
                }
                .padding(12)
                .background(bubbleBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(bubbleStroke, lineWidth: 1.1)
                )
                .shadow(color: isUser ? Color.clear : AppTheme.shadowSoft, radius: 6, x: 0, y: 2)

                Text(Self.timeFormatter.string(from: message.createdAt))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isUser ? AppTheme.textOnAccent.opacity(0.7) : AppTheme.textMuted)
            }

            if !isUser { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

struct CoachChatTypingIndicator: View {
    let reduceMotion: Bool

    var body: some View {
        if reduceMotion {
            Text("思考中")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.textSecondary)
        } else {
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        let phase = time * 2.0 + Double(index) * 0.6
                        let scale = 0.7 + abs(sin(phase)) * 0.4
                        Circle()
                            .fill(AppTheme.textSecondary.opacity(0.6))
                            .frame(width: 5, height: 5)
                            .scaleEffect(scale)
                    }
                }
            }
        }
    }
}
