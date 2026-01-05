import SwiftUI

struct AuthView: View {
    @ObservedObject var vm: AppViewModel
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            liquidGlow
            liquidSheen

            VStack(spacing: 24) {
                mascotHeader

                VStack(spacing: 16) {
                    field(icon: "envelope.fill", placeholder: "Email", text: $email, isSecure: false)
                    field(icon: "lock.fill", placeholder: "Password", text: $password, isSecure: true)
                }
                .glassCard()

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.45))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                if vm.isLoading {
                    ProgressView()
                        .tint(Color(red: 0.45, green: 1.0, blue: 0.75))
                }

                neonButton(title: "Sign In", gradient: [Color(red: 0.3, green: 0.95, blue: 0.75), Color(red: 0.2, green: 0.7, blue: 1.0)]) {
                    Task { await vm.signIn(email: email, password: password) }
                }

                ghostButton(title: "Create Account") {
                    Task { await vm.signUp(email: email, password: password) }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
    }

    private var mascotHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.35, green: 1.0, blue: 0.7), Color(red: 0.45, green: 0.65, blue: 1.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 94, height: 94)
                    .shadow(color: Color(red: 0.35, green: 1.0, blue: 0.85).opacity(0.8), radius: 24, x: 0, y: 12)
                    .shadow(color: Color(red: 0.3, green: 0.7, blue: 1.0).opacity(0.6), radius: 40, x: 0, y: 0)

                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("SAT Quest")
                .font(.title.bold())
                .foregroundStyle(Color(red: 0.92, green: 0.96, blue: 1.0))

            Text("Level up your practice")
                .font(.subheadline)
                .foregroundStyle(Color(red: 0.7, green: 0.82, blue: 0.95))
        }
    }

    private func field(icon: String, placeholder: String, text: Binding<String>, isSecure: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(red: 0.45, green: 1.0, blue: 0.8))
                .frame(width: 28)

            if isSecure {
                SecureField(placeholder, text: text)
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(Color.white)
            } else {
                TextField(placeholder, text: text)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(Color.white)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.clear, Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }

    private func neonButton(title: String, gradient: [Color], action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blendMode(.screen)
                )
                .shadow(color: gradient.first?.opacity(0.8) ?? .clear, radius: 22, x: 0, y: 12)
                .shadow(color: gradient.last?.opacity(0.7) ?? .clear, radius: 36, x: 0, y: 0)
        }
    }

    private func ghostButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color(red: 0.9, green: 0.94, blue: 1.0))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .background(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(red: 0.55, green: 0.9, blue: 1.0).opacity(0.7), lineWidth: 1)
                )
                .shadow(color: Color(red: 0.4, green: 0.85, blue: 1.0).opacity(0.45), radius: 18, x: 0, y: 8)
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.03, green: 0.04, blue: 0.1),
                Color(red: 0.05, green: 0.08, blue: 0.18),
                Color(red: 0.08, green: 0.09, blue: 0.22)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var liquidGlow: some View {
        ZStack {
            RadialGradient(
                colors: [Color(red: 0.3, green: 1.0, blue: 0.8).opacity(0.25), Color.clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 260
            )

            RadialGradient(
                colors: [Color(red: 0.45, green: 0.7, blue: 1.0).opacity(0.22), Color.clear],
                center: .bottomTrailing,
                startRadius: 30,
                endRadius: 320
            )

            RadialGradient(
                colors: [Color.white.opacity(0.12), Color.clear],
                center: .center,
                startRadius: 10,
                endRadius: 240
            )
        }
        .blur(radius: 60)
        .opacity(0.9)
    }

    private var liquidSheen: some View {
        LinearGradient(
            colors: [Color.white.opacity(0.18), Color.clear, Color.white.opacity(0.1)],
            startPoint: .topTrailing,
            endPoint: .bottomLeading
        )
        .blendMode(.screen)
        .ignoresSafeArea()
        .opacity(0.65)
    }
}

private extension View {
    func glassCard() -> some View {
        self
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        LinearGradient(
                            colors: [Color.white.opacity(0.2), Color.clear, Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.5), Color(red: 0.55, green: 0.9, blue: 1.0).opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.4), radius: 22, x: 0, y: 12)
    }
}
