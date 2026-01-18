import SwiftUI

struct CoachChatHeaderView: View {
    let title: String
    let subtitle: String
    let overrideSubtitle: String?
    let onBack: () -> Void
    let onEditSubtitle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            backButton

            HStack(spacing: 10) {
                CoachAvatarView(size: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    subtitleView
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onEditSubtitle()
            }
            .contextMenu {
                Button("编辑副标题", action: onEditSubtitle)
            }

            Spacer(minLength: 0)

            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, AppMetrics.screenHorizontalPadding)
    }

    private var backButton: some View {
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
    }

    private var subtitleView: some View {
        let override = overrideSubtitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let showOverride = !override.isEmpty

        return ZStack(alignment: .leading) {
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .opacity(showOverride ? 0 : 1)

            Text(override)
                .font(.caption)
                .foregroundStyle(AppTheme.textMuted)
                .opacity(showOverride ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.18), value: showOverride)
    }
}
