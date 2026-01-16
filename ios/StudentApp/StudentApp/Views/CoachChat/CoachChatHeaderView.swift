import SwiftUI

struct CoachChatHeaderView: View {
    let statusText: String
    let isStreaming: Bool
    let hasLinkedAttempt: Bool
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
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

            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    CoachAvatarView(size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("王校长")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("AI辅导老师")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(isStreaming ? AppTheme.accentStrong : AppTheme.statusSuccess)
                        .frame(width: 6, height: 6)
                    Text(statusText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.textMuted)

                    if hasLinkedAttempt {
                        Text("本题追问")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(AppTheme.surfaceRaised)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(AppTheme.divider, lineWidth: 1)
                            )
                    }
                }
            }

            Spacer()

            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, AppMetrics.screenHorizontalPadding)
    }
}
