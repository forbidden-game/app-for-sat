import SwiftUI

struct CoachChatDemoCoachCard: View {
    let style: CoachChatDemoStyle

    var body: some View {
        switch style.variant {
        case .warmScholar:
            WarmCoachCard(style: style)
        case .focusMode:
            FocusStrip(style: style)
        case .auroraMentor:
            AuroraCoachCard(style: style)
        }
    }
}

private struct WarmCoachCard: View {
    let style: CoachChatDemoStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今日辅导重点")
                    .font(style.fontLabel)
                    .foregroundStyle(style.textSecondary)
                Spacer()
                Text("代数 · 线性方程")
                    .font(style.fontCaption)
                    .foregroundStyle(style.textOnAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(style.accent)
                    .clipShape(Capsule())
            }

            Text("先写等式结构，再移项。把常数移到右侧时，注意符号变化。")
                .font(style.fontBody)
                .foregroundStyle(style.textPrimary)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(style.surfaceAlt)
                    .frame(height: 6)
                Capsule()
                    .fill(style.accent)
                    .frame(width: 160, height: 6)
            }
        }
        .padding(14)
        .background(style.surface)
        .overlay(
            RoundedRectangle(cornerRadius: style.cardCorner, style: .continuous)
                .stroke(style.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: style.cardCorner, style: .continuous))
    }
}

private struct FocusStrip: View {
    let style: CoachChatDemoStyle

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Focus rule")
                    .font(style.fontCaption)
                    .foregroundStyle(style.textSecondary)
                Text("写出等式结构，再移项。")
                    .font(style.fontBody)
                    .foregroundStyle(style.textPrimary)
            }
            Spacer()
            Text("1m/题")
                .font(style.fontCaption)
                .foregroundStyle(style.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(style.surfaceAlt)
                .clipShape(Capsule())
        }
        .padding(12)
        .background(style.surface)
        .overlay(
            RoundedRectangle(cornerRadius: style.cardCorner, style: .continuous)
                .stroke(style.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: style.cardCorner, style: .continuous))
    }
}

private struct AuroraCoachCard: View {
    let style: CoachChatDemoStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("今日战术")
                    .font(style.fontLabel)
                    .foregroundStyle(style.textSecondary)
                Spacer()
                Text("Confidence 82%")
                    .font(style.fontCaption)
                    .foregroundStyle(style.textOnAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.00, green: 0.65, blue: 0.95), Color(red: 0.98, green: 0.20, blue: 0.60)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }

            Text("把题目拆成 3 个微步骤：列式、移项、化简。")
                .font(style.fontBody)
                .foregroundStyle(style.textPrimary)

            HStack(spacing: 8) {
                CoachChatDemoChip(style: style, label: "线性")
                CoachChatDemoChip(style: style, label: "符号")
                CoachChatDemoChip(style: style, label: "检验")
            }
        }
        .padding(14)
        .background(style.surface)
        .overlay(
            RoundedRectangle(cornerRadius: style.cardCorner, style: .continuous)
                .stroke(style.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: style.cardCorner, style: .continuous))
    }
}

struct CoachChatDemoMessages: View {
    let style: CoachChatDemoStyle
    private var messages: [CoachChatDemoMessage] {
        CoachChatDemoMessage.samples(for: style.variant)
    }

    var body: some View {
        switch style.variant {
        case .focusMode:
            VStack(spacing: 0) {
                ForEach(messages.indices, id: \.self) { index in
                    CoachChatFocusRow(style: style, message: messages[index])
                    if index < messages.count - 1 {
                        Divider()
                            .background(style.border)
                    }
                }
            }
            .padding(12)
            .background(style.surface)
            .overlay(
                RoundedRectangle(cornerRadius: style.cardCorner, style: .continuous)
                    .stroke(style.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: style.cardCorner, style: .continuous))
        case .warmScholar:
            VStack(spacing: style.messageSpacing) {
                ForEach(messages) { message in
                    CoachChatDemoBubble(style: style, message: message)
                }
            }
        case .auroraMentor:
            VStack(spacing: style.messageSpacing) {
                ForEach(messages) { message in
                    CoachChatDemoBubble(style: style, message: message)
                }
            }
            .padding(12)
            .background(style.surface.opacity(0.92))
            .overlay(
                RoundedRectangle(cornerRadius: style.cardCorner, style: .continuous)
                    .stroke(style.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: style.cardCorner, style: .continuous))
        }
    }
}

private struct CoachChatDemoBubble: View {
    let style: CoachChatDemoStyle
    let message: CoachChatDemoMessage

    var body: some View {
        let isUser = message.role == .user
        let bubbleStyle = isUser ? style.userBubble : style.assistantBubble
        let textColor = isUser ? style.textOnAccent : style.textPrimary
        let strokeColor = isUser ? style.border : style.assistantStroke

        return HStack(alignment: .top, spacing: 10) {
            if !isUser {
                Circle()
                    .fill(style.accent)
                    .frame(width: 26, height: 26)
                    .overlay(
                        Text("AI")
                            .font(style.fontCaption)
                            .foregroundStyle(style.textOnAccent)
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                switch message.content {
                case .text(let text):
                    Text(text)
                        .font(style.fontBody)
                        .foregroundStyle(textColor)
                        .fixedSize(horizontal: false, vertical: true)
                case .audio(let duration):
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(duration)
                            .font(style.fontCaption)
                    }
                    .foregroundStyle(textColor)
                case .image:
                    RoundedRectangle(cornerRadius: style.cardCorner, style: .continuous)
                        .fill(style.surfaceAlt)
                        .frame(width: 160, height: 110)
                        .overlay(
                            Image(systemName: "doc.viewfinder")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(textColor.opacity(0.7))
                        )
                }

                if message.isStreaming {
                    Text("…")
                        .font(style.fontCaption)
                        .foregroundStyle(textColor.opacity(0.7))
                }
            }
            .padding(12)
            .background(bubbleStyle)
            .clipShape(RoundedRectangle(cornerRadius: style.bubbleCorner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: style.bubbleCorner, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
            )

            if isUser { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}

private struct CoachChatFocusRow: View {
    let style: CoachChatDemoStyle
    let message: CoachChatDemoMessage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .assistant {
                Text("Coach")
                    .font(style.fontCaption)
                    .foregroundStyle(style.textSecondary)
                    .frame(width: 54, alignment: .leading)
            } else {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                switch message.content {
                case .text(let text):
                    Text(text)
                        .font(style.fontBody)
                        .foregroundStyle(style.textPrimary)
                        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                case .audio(let duration):
                    FocusAudioMessage(style: style, duration: duration)
                        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                case .image(let caption):
                    FocusImageMessage(style: style, caption: caption)
                        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                }

                if message.isStreaming {
                    Text("…")
                        .font(style.fontCaption)
                        .foregroundStyle(style.textSecondary)
                }
            }

            if message.role == .user {
                Text("You")
                    .font(style.fontCaption)
                    .foregroundStyle(style.textSecondary)
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .padding(.vertical, 8)
    }
}

struct CoachChatDemoComposer: View {
    let style: CoachChatDemoStyle

    var body: some View {
        VStack(spacing: 8) {
            if style.variant != .focusMode {
                HStack(spacing: 8) {
                    CoachChatDemoChip(style: style, label: "解释移项")
                    CoachChatDemoChip(style: style, label: "再出一题")
                    CoachChatDemoChip(style: style, label: "总结要点")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if style.variant == .focusMode {
                FocusRecordingBar(style: style)
                FocusComposerRow(style: style)
            } else {
                HStack(spacing: 10) {
                    Text("问老师一个问题…")
                        .font(style.fontBody)
                        .foregroundStyle(style.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(style.surfaceAlt)
                        .clipShape(RoundedRectangle(cornerRadius: style.cardCorner, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: style.cardCorner, style: .continuous)
                                .stroke(style.border, lineWidth: 1)
                        )

                    Circle()
                        .fill(style.accent)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(style.textOnAccent)
                        )
                }
            }
        }
    }
}

struct CoachChatDemoChip: View {
    let style: CoachChatDemoStyle
    let label: String

    var body: some View {
        Text(label)
            .font(style.fontCaption)
            .foregroundStyle(style.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(style.chipBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(style.chipStroke, lineWidth: 1)
            )
    }
}
