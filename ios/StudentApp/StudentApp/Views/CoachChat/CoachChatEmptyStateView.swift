import SwiftUI

struct CoachChatEmptyStateView: View {
    let prompts: [String]
    let onPromptTap: (String) -> Void
    let onCameraTap: () -> Void
    let onMicTap: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                CoachAvatarView(size: 40)

                VStack(alignment: .leading, spacing: 6) {
                    Text("王校长在这儿")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("把题目发给我，或用语音说出你卡住的步骤。我们一起拆解。")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                CoachChatQuickActionButton(
                    icon: "camera.fill",
                    title: "拍题",
                    action: onCameraTap
                )
                CoachChatQuickActionButton(
                    icon: "mic.fill",
                    title: "语音",
                    action: onMicTap
                )
            }

            if !prompts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("你可以这样问")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textMuted)

                    FlowLayout(spacing: 8) {
                        ForEach(prompts, id: \.self) { prompt in
                            CoachChatPromptChip(title: prompt) {
                                onPromptTap(prompt)
                            }
                        }
                    }
                }
            }
        }
        .padding(AppMetrics.cardPadding)
        .background(AppTheme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.dividerStrong, lineWidth: 1.2)
        )
        .shadow(color: AppTheme.shadowSoft, radius: 12, x: 0, y: 4)
    }
}

private struct CoachChatQuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.footnote.weight(.semibold))
            }
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.divider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CoachChatPromptChip: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(AppTheme.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppTheme.divider, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: maxWidth, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(width: size.width, height: size.height))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
