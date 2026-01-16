import AVFoundation
import SwiftUI

struct RecordingBar: View {
    let startedAt: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsedText = Self.formatElapsed(from: startedAt, now: timeline.date)
            HStack(spacing: 10) {
                Circle()
                    .fill(AppTheme.statusDanger)
                    .frame(width: 8, height: 8)

                Text("录音中 \(elapsedText)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)

                Spacer()

                RecordingWave(reduceMotion: reduceMotion)
                    .frame(width: 88, height: 16)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.dividerStrong, lineWidth: 1.2)
            )
        }
    }

    private static func formatElapsed(from start: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%02d:%02d", minutes, remainder)
    }
}

private struct RecordingWave: View {
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<8, id: \.self) { index in
                    let phase = time * 2.2 + Double(index) * 0.6
                    let height = 4 + abs(sin(phase)) * 10
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.accent)
                        .frame(width: 2, height: reduceMotion ? 8 : height)
                }
            }
        }
    }
}

struct AudioMessageBubble: View {
    let payload: CoachChatAudioPayload
    let isUser: Bool
    let foreground: Color
    let isPlaying: Bool
    let progress: Double
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 8) {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 12, weight: .bold))

                Text(displayTimeText)
                    .font(.caption.weight(.semibold))
                    .frame(width: 40, alignment: .leading)

                AudioWaveform(
                    progress: progress,
                    baseColor: foreground.opacity(0.35),
                    progressColor: foreground.opacity(0.9)
                )
            }
            .frame(width: bubbleWidth, alignment: .leading)
            .foregroundStyle(foreground)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "停止播放语音" : "播放语音")
    }

    private var displayTimeText: String {
        if isPlaying {
            let currentSeconds = max(0, Int(Double(payload.duration) * min(max(progress, 0), 1)))
            return Self.format(seconds: currentSeconds)
        }
        let totalSeconds = max(0, Int(payload.duration.rounded()))
        return Self.format(seconds: totalSeconds)
    }

    private static func format(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%d:%02d", minutes, remainder)
    }

    private var bubbleWidth: CGFloat {
        let minWidth: CGFloat = 100
        let maxWidth: CGFloat = 240
        let width = 96 + CGFloat(payload.duration) * 6
        return min(max(width, minWidth), maxWidth)
    }
}

struct AudioWaveform: View {
    let progress: Double
    let baseColor: Color
    let progressColor: Color

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 20)
            let barCount = max(Int(width / 4), 6)
            let clampedProgress = min(max(progress, 0), 1)

            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(baseColor)
                        .frame(width: 2, height: barHeight(for: index))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                HStack(spacing: 2) {
                    ForEach(0..<barCount, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(progressColor)
                            .frame(width: 2, height: barHeight(for: index))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .mask(
                    HStack(spacing: 0) {
                        Rectangle()
                            .frame(width: width * clampedProgress)
                        Spacer(minLength: 0)
                    }
                )
            )
        }
        .frame(maxWidth: .infinity, minHeight: 14, maxHeight: 14)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let pattern = [4, 7, 10, 6, 9, 5, 8, 6]
        return CGFloat(pattern[index % pattern.count])
    }
}

final class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    var onFinish: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
    }
}
