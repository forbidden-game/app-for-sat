import SwiftUI
import UIKit
import StudentCore

struct CoachChatMessageRow: View {
    let message: CoachThreadMessage
    let previousMessage: CoachThreadMessage?
    let nextMessage: CoachThreadMessage?
    let replyMessage: CoachThreadMessage?

    let playingMessageId: String?
    let playbackProgress: Double
    let onPlayAudio: (String, CoachChatAudioPayload) -> Void
    let onReply: (CoachThreadMessage) -> Void
    let onTapReply: (String) -> Void

    var body: some View {
        VStack(spacing: 6) {
            if showsTimestampSeparator {
                ChatTimestampPill(date: message.createdAt)
                    .frame(maxWidth: .infinity)
            }

            CoachChatMessageBubble(
                message: message,
                replyMessage: replyMessage,
                showAssistantAvatar: showAssistantAvatar,
                playingMessageId: playingMessageId,
                playbackProgress: playbackProgress,
                onPlayAudio: onPlayAudio,
                onTapReply: onTapReply
            )
            .contextMenu {
                if message.role != .tool {
                    Button {
                        onReply(message)
                    } label: {
                        Label("引用", systemImage: "quote.bubble")
                    }
                }
            }
        }
        .padding(.top, rowTopPadding)
    }

    private var showsTimestampSeparator: Bool {
        guard let previousMessage else { return true }
        return message.createdAt.timeIntervalSince(previousMessage.createdAt) > timestampGapThreshold
    }

    private var showAssistantAvatar: Bool {
        guard message.role == .assistant else { return false }
        guard let nextMessage else { return true }

        if nextMessage.role != .assistant {
            return true
        }

        return nextMessage.createdAt.timeIntervalSince(message.createdAt) > groupGapThreshold
    }

    private var rowTopPadding: CGFloat {
        guard let previousMessage else { return 12 }

        let gap = message.createdAt.timeIntervalSince(previousMessage.createdAt)

        if gap > timestampGapThreshold {
            return 12
        }

        if previousMessage.role == message.role, gap < groupGapThreshold {
            return 4
        }

        return 10
    }

    private let timestampGapThreshold: TimeInterval = 5 * 60
    private let groupGapThreshold: TimeInterval = 90
}

private struct ChatTimestampPill: View {
    let date: Date

    var body: some View {
        Text(Self.format(date: date))
            .font(.caption2.weight(.medium))
            .foregroundStyle(AppTheme.textMuted)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(AppTheme.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.divider, lineWidth: 1)
            )
    }

    private static func format(date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = .current

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }

        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }
}

struct CoachChatMessageBubble: View {
    let message: CoachThreadMessage
    let replyMessage: CoachThreadMessage?
    let showAssistantAvatar: Bool

    let playingMessageId: String?
    let playbackProgress: Double
    let onPlayAudio: (String, CoachChatAudioPayload) -> Void
    let onTapReply: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        let audioPayload = CoachChatAudioPayload.parse(from: message.content.text)
        let imagePayload = CoachChatImagePayload.parse(from: message.content.text)

        let foreground = isUser ? AppTheme.textOnAccent : AppTheme.textPrimary
        let bubbleBackground = isUser ? AppTheme.accentStrong : AppTheme.surfaceRaised
        let bubbleStroke = isUser ? Color.clear : AppTheme.divider

        return HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer(minLength: 52)
            } else {
                avatarSlot
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                if let replyMessage {
                    CoachChatReplyPreview(
                        message: replyMessage,
                        isUser: isUser,
                        onTap: { onTapReply(replyMessage.id) }
                    )
                }

                if let audioPayload {
                    AudioMessageBubble(
                        payload: audioPayload,
                        isUser: isUser,
                        foreground: foreground,
                        isPlaying: playingMessageId == message.id,
                        progress: playingMessageId == message.id ? playbackProgress : 0,
                        onPlay: { onPlayAudio(message.id, audioPayload) }
                    )
                } else if let imagePayload {
                    CoachChatImageBubble(
                        payload: imagePayload,
                        isUser: isUser,
                        foreground: foreground
                    )
                } else {
                    CoachChatBubbleText(
                        text: message.content.text,
                        style: .chatBubble(isUser: isUser),
                        textColor: foreground,
                        maxWidth: bubbleMaxWidth,
                        alignment: isUser ? .trailing : .leading
                    )
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
                    .stroke(bubbleStroke, lineWidth: 1)
            )
            .shadow(color: isUser ? Color.clear : AppTheme.shadowSoft, radius: 5, x: 0, y: 2)

            if !isUser {
                Spacer(minLength: 52)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var bubbleMaxWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        return screenWidth * 0.72
    }

    private var avatarSlot: some View {
        let size: CGFloat = 26

        return Group {
            if showAssistantAvatar {
                CoachAvatarView(size: size)
            } else {
                Color.clear
                    .frame(width: size, height: size)
            }
        }
        .padding(.bottom, 2)
    }
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

private struct CoachChatReplyPreview: View {
    let message: CoachThreadMessage
    let isUser: Bool
    let onTap: () -> Void

    var body: some View {
        let titleColor = isUser ? AppTheme.textOnAccent.opacity(0.75) : AppTheme.textSecondary
        let textColor = isUser ? AppTheme.textOnAccent.opacity(0.9) : AppTheme.textPrimary
        let background = isUser ? AppTheme.textOnAccent.opacity(0.12) : AppTheme.surface
        let stroke = isUser ? AppTheme.textOnAccent.opacity(0.2) : AppTheme.divider

        return VStack(alignment: .leading, spacing: 4) {
            Text(message.replyAuthorLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(titleColor)
            Text(message.replyPreviewText)
                .font(.caption)
                .foregroundStyle(textColor)
                .lineLimit(2)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(stroke, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture(perform: onTap)
    }
}

private struct CoachChatBubbleText: View {
    let text: String
    let style: MathTextStyle
    let textColor: Color
    let maxWidth: CGFloat
    let alignment: Alignment

    var body: some View {
        MathTextView(
            text: text,
            style: style,
            textColor: textColor,
            expandsHorizontally: false
        )
        .frame(width: bubbleWidth, alignment: alignment)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var bubbleWidth: CGFloat {
        let width = max(lineWidth, 0)
        return min(width, maxWidth)
    }

    private var lineWidth: CGFloat {
        let font = UIFont.systemFont(ofSize: style.fontSize, weight: uiFontWeight)
        let lines = text.components(separatedBy: .newlines)
        let widths = lines.map { line -> CGFloat in
            (line as NSString).size(withAttributes: [.font: font]).width
        }
        return ceil(widths.max() ?? 0)
    }

    private var uiFontWeight: UIFont.Weight {
        switch style.fontWeight {
        case .ultraLight:
            return .ultraLight
        case .thin:
            return .thin
        case .light:
            return .light
        case .medium:
            return .medium
        case .semibold:
            return .semibold
        case .bold:
            return .bold
        case .heavy:
            return .heavy
        case .black:
            return .black
        default:
            return .regular
        }
    }
}

private struct CoachChatImageBubble: View {
    let payload: CoachChatImagePayload
    let isUser: Bool
    let foreground: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = CoachChatImageStore.loadImage(fileName: payload.fileName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageSize.width, height: imageSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.divider, lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.surface)
                    .frame(width: imageSize.width, height: imageSize.height)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(foreground.opacity(0.6))
                    )
            }

            if let caption = payload.caption, !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                MathTextView(
                    text: caption,
                    style: .chatBubble(isUser: isUser),
                    textColor: foreground,
                    expandsHorizontally: false
                )
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var imageSize: CGSize {
        let maxWidth: CGFloat = 220
        let width = payload.width > 0 ? min(maxWidth, payload.width) : maxWidth
        let ratio = payload.width > 0 && payload.height > 0 ? payload.height / payload.width : 0.75
        let height = max(120, width * ratio)
        return CGSize(width: width, height: height)
    }
}

extension CoachThreadMessage {
    var replyAuthorLabel: String {
        switch role {
        case .assistant:
            return "王校长"
        case .user:
            return "我"
        case .tool:
            return "系统"
        }
    }

    var replyPreviewText: String {
        let trimmed = content.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if CoachChatAudioPayload.parse(from: trimmed) != nil {
            return "语音消息"
        }
        if let imagePayload = CoachChatImagePayload.parse(from: trimmed) {
            let caption = imagePayload.caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return caption.isEmpty ? "图片" : "图片：\(caption)"
        }
        if trimmed.isEmpty {
            return "（空消息）"
        }
        let maxChars = 80
        if trimmed.count > maxChars {
            return String(trimmed.prefix(maxChars)) + "…"
        }
        return trimmed
    }
}
