import SwiftUI

struct FocusRecordingBar: View {
    let style: CoachChatDemoStyle

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)

            Text("录音中 00:12")
                .font(style.fontCaption)
                .foregroundStyle(style.textSecondary)

            Spacer()

            FocusWaveform(style: style)
                .frame(width: 88, height: 16)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(style.surface)
        .overlay(
            RoundedRectangle(cornerRadius: style.cardCorner, style: .continuous)
                .stroke(style.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: style.cardCorner, style: .continuous))
    }
}

private struct FocusWaveform: View {
    let style: CoachChatDemoStyle

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<8, id: \.self) { index in
                    let phase = time * 2.4 + Double(index) * 0.6
                    let height = 4 + abs(sin(phase)) * 10
                    RoundedRectangle(cornerRadius: 2)
                        .fill(style.accent)
                        .frame(width: 2, height: height)
                }
            }
        }
    }
}

struct FocusComposerRow: View {
    let style: CoachChatDemoStyle

    var body: some View {
        HStack(spacing: 10) {
            FocusIconButton(systemName: "camera", style: style, filled: false)

            Text("输入或粘贴题目…")
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

            FocusIconButton(systemName: "mic.fill", style: style, filled: true)
        }
    }
}

private struct FocusIconButton: View {
    let systemName: String
    let style: CoachChatDemoStyle
    let filled: Bool

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(filled ? style.textOnAccent : style.textSecondary)
            .frame(width: 40, height: 40)
            .background(filled ? style.accent : style.surface)
            .clipShape(RoundedRectangle(cornerRadius: style.cardCorner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: style.cardCorner, style: .continuous)
                    .stroke(style.border, lineWidth: 1)
            )
    }
}

struct FocusAudioMessage: View {
    let style: CoachChatDemoStyle
    let duration: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "play.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(style.textPrimary)

            Text(duration)
                .font(style.fontCaption)
                .foregroundStyle(style.textPrimary)

            FocusMiniWave(style: style)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(style.surfaceAlt)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(style.border, lineWidth: 1)
        )
    }
}

private struct FocusMiniWave: View {
    let style: CoachChatDemoStyle

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<6, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(style.textSecondary)
                    .frame(width: 2, height: 4 + CGFloat(index % 3) * 2)
            }
        }
    }
}

struct FocusImageMessage: View {
    let style: CoachChatDemoStyle
    let caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: style.cardCorner, style: .continuous)
                    .fill(style.surfaceAlt)
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: style.cardCorner, style: .continuous)
                            .stroke(style.border, lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "doc.viewfinder")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(style.textSecondary)
                    )

                Text("IMG")
                    .font(style.fontCaption)
                    .foregroundStyle(style.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(style.surface)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(style.border, lineWidth: 1)
                    )
                    .padding(8)
            }

            if let caption {
                Text(caption)
                    .font(style.fontCaption)
                    .foregroundStyle(style.textSecondary)
            }
        }
    }
}
