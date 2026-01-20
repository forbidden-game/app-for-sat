import SwiftUI
import StudentCore

struct FriendProfileView: View {
    let friend: FriendThreadSummary
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            ModalTopBar(
                title: "个人主页",
                showsClose: true,
                leadingSystemImage: "chevron.left",
                onClose: { dismiss() }
            )

            VStack(spacing: 10) {
                AvatarView(avatarUrl: friend.avatarUrl, placeholder: initials, size: 72)

                Text(friend.username)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                if let rating = friend.rating {
                    HStack(spacing: 6) {
                        Image(systemName: "sun.max.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.statusWarning)
                        Text("\(rating)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .padding(.top, 12)

            Spacer()
        }
        .padding(.horizontal, AppMetrics.screenHorizontalPadding)
        .padding(.bottom, AppMetrics.screenBottomPadding)
        .background(AppTheme.backgroundGradient.ignoresSafeArea())
    }

    private var initials: String {
        let parts = friend.username.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }
        let text = letters.map { String($0) }.joined()
        return text.isEmpty ? "?" : text.uppercased()
    }
}
