import SwiftUI

// MARK: - General Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AppTheme.textMuted)

            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.textSecondary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textMuted)
                .multilineTextAlignment(.center)

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textOnAccent)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 24)
                        .background(AppTheme.accentStrong)
                        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.rowCornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppMetrics.screenHorizontalPadding * 2)
    }
}

// MARK: - Friends Empty State

struct FriendsEmptyStateView: View {
    let onInvite: () -> Void

    var body: some View {
        EmptyStateView(
            icon: "person.2.slash",
            title: "暂无好友",
            message: "开始添加好友一起学习吧",
            actionTitle: "邀请好友",
            action: onInvite
        )
    }
}

// MARK: - History Empty State

struct HistoryEmptyStateView: View {
    var body: some View {
        EmptyStateView(
            icon: "clock.slash",
            title: "暂无练习记录",
            message: "开始练习来记录你的学习进度吧"
        )
    }
}

// MARK: - Chat Empty State

struct ChatEmptyStateView: View {
    var body: some View {
        EmptyStateView(
            icon: "bubble.left.and.bubble.right",
            title: "开始对话",
            message: "发送消息与 AI 辅导老师交流"
        )
    }
}

// MARK: - Error Card

struct ErrorCard: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.statusDanger)

            Text(message)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.surface)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(AppTheme.statusDanger.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.statusDanger.opacity(0.3), lineWidth: 1)
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Toast

struct AppToast: View {
    let message: String
    let type: ToastType
    let onDismiss: () -> Void

    enum ToastType {
        case success
        case error
        case warning
        case info

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .success: return AppTheme.statusSuccess
            case .error: return AppTheme.statusDanger
            case .warning: return AppTheme.statusWarning
            case .info: return AppTheme.accentStrong
            }
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: type.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(type.color)

            Text(message)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(AppTheme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.divider, lineWidth: 1)
        )
        .shadow(color: AppTheme.shadowSoft, radius: 10, x: 0, y: 4)
    }
}

// MARK: - Preview

#Preview("Empty States") {
    ZStack {
        AppTheme.backgroundGradient
            .ignoresSafeArea()

        ScrollView {
            VStack(spacing: 40) {
                EmptyStateView(
                    icon: "person.2.slash",
                    title: "暂无好友",
                    message: "开始添加好友一起学习吧",
                    actionTitle: "邀请好友",
                    action: { print("Invite tapped") }
                )

                Divider()
                    .background(AppTheme.divider)

                HistoryEmptyStateView()

                Divider()
                    .background(AppTheme.divider)

                ChatEmptyStateView()

                Divider()
                    .background(AppTheme.divider)

                ErrorCard(message: "网络连接失败，请重试") {
                    print("Dismiss error")
                }
            }
            .padding(20)
        }
    }
}
