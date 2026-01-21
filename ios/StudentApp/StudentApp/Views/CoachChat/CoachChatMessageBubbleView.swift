import SwiftUI
import UIKit
import CoreText
import StudentCore

private enum CoachChatRenderCache {
    static let parser = MathMarkupParser()
    static let requiresMathCache: NSCache<NSString, NSNumber> = {
        let cache = NSCache<NSString, NSNumber>()
        cache.countLimit = 400
        return cache
    }()

    static func requiresMath(for text: String) -> Bool {
        if let cached = requiresMathCache.object(forKey: text as NSString) {
            return cached.boolValue
        }
        let requires = parser.parse(text).requiresMathRendering
        requiresMathCache.setObject(NSNumber(value: requires), forKey: text as NSString)
        return requires
    }
}

private enum CoachChatTextWidthCache {
    static let cache: NSCache<NSString, NSNumber> = {
        let cache = NSCache<NSString, NSNumber>()
        cache.countLimit = 300
        return cache
    }()

    static func width(for text: String, font: UIFont) -> CGFloat? {
        let key = cacheKey(for: text, font: font)
        guard let cached = cache.object(forKey: key as NSString) else { return nil }
        return CGFloat(cached.doubleValue)
    }

    static func store(_ width: CGFloat, for text: String, font: UIFont) {
        let key = cacheKey(for: text, font: font)
        cache.setObject(NSNumber(value: Double(width)), forKey: key as NSString)
    }

    private static func cacheKey(for text: String, font: UIFont) -> String {
        "\(font.fontName)|\(font.pointSize)|\(text)"
    }
}

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
                    let usePlainTextLabel = isUser && !CoachChatRenderCache.requiresMath(for: message.content.text)
                    CoachChatBubbleText(
                        text: message.content.text,
                        style: .chatBubble(isUser: isUser),
                        textColor: foreground,
                        maxWidth: bubbleMaxWidth,
                        usePlainTextLabel: usePlainTextLabel
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
    let usePlainTextLabel: Bool

    var body: some View {
        Group {
            if usePlainTextLabel {
                CoachChatPlainTextLabel(
                    text: text,
                    font: uiFont,
                    textColor: textColor,
                    lineSpacing: style.lineSpacing,
                    maxWidth: bubbleWidth
                )
            } else {
                MathTextView(
                    text: text,
                    style: style,
                    textColor: textColor,
                    expandsHorizontally: false
                )
            }
        }
        .frame(width: bubbleWidth, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var bubbleWidth: CGFloat {
        min(textLayoutWidth, maxWidth)
    }

    private var textLayoutWidth: CGFloat {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }

        if trimmed.count > 200 {
            return maxWidth
        }

        // Decouple bubble sizing from auto-wrapping.
        // - If the whole message fits on one line (under maxWidth), shrink bubble to that width.
        // - If it doesn't fit, use maxWidth and let the renderer decide wrapping.
        // This avoids a feedback loop where a slightly-too-small width causes an extra wrap,
        // which then makes the bubble even narrower ("too hard" -> "too\nhard" -> word-per-line).
        let attributes: [NSAttributedString.Key: Any] = [
            .font: uiFont
        ]

        let scale = UIScreen.main.scale
        func roundUpToPixel(_ value: CGFloat) -> CGFloat {
            ceil(value * scale) / scale
        }

        if let cached = CoachChatTextWidthCache.width(for: trimmed, font: uiFont) {
            if cached >= maxWidth {
                return maxWidth
            }
            return roundUpToPixel(cached + 2)
        }

        let explicitLines = trimmed.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        var maxExplicitLineWidth: CGFloat = 0

        for lineSub in explicitLines {
            let line = String(lineSub)
            let attributed = NSAttributedString(string: line, attributes: attributes)
            let ctLine = CTLineCreateWithAttributedString(attributed)
            let width = CTLineGetTypographicBounds(ctLine, nil, nil, nil)
            let trailing = CTLineGetTrailingWhitespaceWidth(ctLine)
            maxExplicitLineWidth = max(maxExplicitLineWidth, max(0, CGFloat(width) - trailing))
        }

        CoachChatTextWidthCache.store(maxExplicitLineWidth, for: trimmed, font: uiFont)

        if maxExplicitLineWidth >= maxWidth {
            return maxWidth
        }

        // Tiny safety padding to avoid accidental wraps from fractional metrics.
        return roundUpToPixel(maxExplicitLineWidth + 2)
    }

    private var uiFont: UIFont {
        UIFont.systemFont(ofSize: style.fontSize, weight: uiFontWeight)
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

private struct CoachChatPlainTextLabel: UIViewRepresentable {
    let text: String
    let font: UIFont
    let textColor: Color
    let lineSpacing: CGFloat
    let maxWidth: CGFloat

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .left
        label.backgroundColor = .clear
        label.isOpaque = false
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.preferredMaxLayoutWidth = maxWidth
        label.attributedText = attributedText()
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
    }

    private func attributedText() -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.alignment = .left
        paragraphStyle.lineSpacing = lineSpacing
        paragraphStyle.hyphenationFactor = 0
        if #available(iOS 14.0, *) {
            paragraphStyle.lineBreakStrategy = [.pushOut]
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(textColor),
            .paragraphStyle: paragraphStyle
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }
}

private struct CoachChatImageBubble: View {
    let payload: CoachChatImagePayload
    let isUser: Bool
    let foreground: Color

    @State private var loadedImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = loadedImage {
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
        .task(id: payload.fileName) {
            loadedImage = nil
            loadedImage = await CoachChatImageStore.loadImageAsync(fileName: payload.fileName)
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
