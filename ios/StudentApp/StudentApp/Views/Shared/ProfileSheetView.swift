import SwiftUI

struct ProfileSheetView: View {
    let displayName: String
    let onSignOut: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            ModalTopBar(title: "个人信息", showsClose: true, onClose: { dismiss() })

            VStack(spacing: 12) {
                ProfileAvatarView(initials: initials)
                    .frame(width: 72, height: 72)

                Text(displayName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .padding(.top, 8)

            Button(action: onSignOut) {
                Text("退出登录")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.accentStrong)
                    .clipShape(RoundedRectangle(cornerRadius: AppMetrics.rowCornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)

            Spacer()
        }
        .padding(.horizontal, AppMetrics.screenHorizontalPadding)
        .padding(.bottom, AppMetrics.screenBottomPadding)
        .background(AppTheme.backgroundGradient.ignoresSafeArea())
    }

    private var initials: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }
        let text = letters.map { String($0) }.joined()
        return text.isEmpty ? "S" : text.uppercased()
    }
}
