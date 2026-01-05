import SwiftUI

struct AuthView: View {
    @ObservedObject var vm: AppViewModel
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.08, blue: 0.14), Color(red: 0.08, green: 0.12, blue: 0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            neonOrbs

            VStack(spacing: 24) {
                mascotHeader

                VStack(spacing: 16) {
                    field(icon: "envelope.fill", placeholder: "Email", text: $email, isSecure: false)
                    field(icon: "lock.fill", placeholder: "Password", text: $password, isSecure: true)
                }

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

                Button {
                    Task { await vm.signIn(email: email, password: password) }
                } label: {
                    Text("Sign In")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.25, green: 0.9, blue: 0.7), Color(red: 0.2, green: 0.6, blue: 1.0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color(red: 0.35, green: 1.0, blue: 0.8).opacity(0.5), radius: 14, x: 0, y: 8)
                }

                Button {
                    Task { await vm.signUp(email: email, password: password) }
                } label: {
                    Text("Create Account")
                        .font(.headline)
                        .foregroundStyle(Color(red: 0.85, green: 0.9, blue: 1.0))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color(red: 0.35, green: 0.75, blue: 1.0).opacity(0.6), lineWidth: 1)
                        )
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
                            colors: [Color(red: 0.3, green: 0.95, blue: 0.7), Color(red: 0.35, green: 0.65, blue: 1.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 92, height: 92)
                    .shadow(color: Color(red: 0.35, green: 0.9, blue: 1.0).opacity(0.6), radius: 16, x: 0, y: 8)

                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("SAT Quest")
                .font(.title.bold())
                .foregroundStyle(Color(red: 0.9, green: 0.95, blue: 1.0))

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
                .fill(Color.white.opacity(0.08))
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 14, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(red: 0.3, green: 0.8, blue: 1.0).opacity(0.25), lineWidth: 1)
        )
    }

    private var neonOrbs: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.25, green: 0.8, blue: 1.0).opacity(0.25))
                .frame(width: 260, height: 260)
                .blur(radius: 2)
                .offset(x: 160, y: -220)

            Circle()
                .fill(Color(red: 0.3, green: 1.0, blue: 0.75).opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 2)
                .offset(x: -170, y: 240)

            Circle()
                .fill(Color(red: 0.6, green: 0.4, blue: 1.0).opacity(0.15))
                .frame(width: 200, height: 200)
                .blur(radius: 1)
                .offset(x: -140, y: -260)
        }
    }
}
