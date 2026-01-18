import SwiftUI

struct CoachChatEmptyStateView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CoachAvatarView(size: 36)

            VStack(alignment: .leading, spacing: 6) {
                Text("王校长")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                Text("直接发消息开始聊天。错题追问会自动附上上下文。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(AppMetrics.cardPadding)
        .background(AppTheme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.dividerStrong, lineWidth: 1.0)
        )
        .shadow(color: AppTheme.shadowSoft, radius: 10, x: 0, y: 4)
    }
}
