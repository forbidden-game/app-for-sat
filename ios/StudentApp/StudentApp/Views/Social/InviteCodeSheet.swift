import SwiftUI

struct InviteCodeSheet: View {
    @Binding var code: String
    let errorMessage: String?
    let isSubmitting: Bool
    let onCancel: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ModalTopBar(
                title: "输入邀请码",
                showsClose: true,
                onClose: onCancel
            )

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textMuted)

                    TextField("请输入好友邀请码", text: $code)
                        .textInputAutocapitalization(.never)
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(AppTheme.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.divider, lineWidth: 1)
                )

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.statusDanger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Button(action: onSubmit) {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView()
                            .tint(AppTheme.textOnAccent)
                    }
                    Text(isSubmitting ? "提交中" : "确认添加")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textOnAccent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppTheme.accentStrong)
                .clipShape(RoundedRectangle(cornerRadius: AppMetrics.rowCornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting)

            Spacer()
        }
        .padding(.horizontal, AppMetrics.screenHorizontalPadding)
        .padding(.bottom, AppMetrics.screenBottomPadding)
        .background(AppTheme.backgroundGradient.ignoresSafeArea())
    }
}
