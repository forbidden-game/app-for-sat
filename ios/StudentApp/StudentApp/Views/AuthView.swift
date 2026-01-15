import SwiftUI

struct AuthView: View {
    @ObservedObject var vm: AppViewModel
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: AppMetrics.sectionSpacingLarge) {
                header

                VStack(spacing: AppMetrics.sectionSpacing) {
                    field(icon: "envelope.fill", placeholder: "Email", text: $email, isSecure: false)
                    field(icon: "lock.fill", placeholder: "Password", text: $password, isSecure: true)
                }
                .appCard()

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.statusDanger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                if vm.isLoading {
                    ProgressView()
                        .tint(AppTheme.accentStrong)
                }

                primaryButton(title: "Sign In") {
                    Task { await vm.signIn(email: email, password: password) }
                }

                secondaryButton(title: "Create Account") {
                    Task { await vm.signUp(email: email, password: password) }
                }

                Spacer()
            }
            .padding(.horizontal, AppMetrics.screenHorizontalPadding)
            .padding(.top, AppMetrics.screenTopPadding)
        }
    }

    private var header: some View {
        VStack(spacing: AppMetrics.headerSpacing) {
            Text("SAT Practice")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Sign in to continue")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private func field(icon: String, placeholder: String, text: Binding<String>, isSecure: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 28)

            if isSecure {
                SecureField(placeholder, text: text)
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(AppTheme.textPrimary)
            } else {
                TextField(placeholder, text: text)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
        .padding(.vertical, AppMetrics.fieldPaddingVertical)
        .padding(.horizontal, AppMetrics.fieldPaddingHorizontal)
        .appSurface(
            fill: AppTheme.surface,
            stroke: AppTheme.dividerStrong
        )
    }

    private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppMetrics.primaryButtonPaddingVertical)
                .background(
                    RoundedRectangle(cornerRadius: AppMetrics.rowCornerRadius, style: .continuous)
                        .fill(AppTheme.accentStrong)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppMetrics.rowCornerRadius, style: .continuous)
                        .stroke(AppTheme.accent, lineWidth: 1)
                )
                .shadow(color: AppTheme.shadowStrong, radius: AppMetrics.cardShadowRadius, x: 0, y: AppMetrics.cardShadowY)
        }
    }

    private func secondaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppMetrics.primaryButtonPaddingVertical)
                .background(
                    RoundedRectangle(cornerRadius: AppMetrics.rowCornerRadius, style: .continuous)
                        .fill(AppTheme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppMetrics.rowCornerRadius, style: .continuous)
                        .stroke(AppTheme.divider, lineWidth: 1)
                )
                .shadow(color: AppTheme.shadowSoft, radius: AppMetrics.rowShadowRadius, x: 0, y: AppMetrics.rowShadowY)
        }
    }
}
