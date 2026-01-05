import SwiftUI

struct AuthView: View {
    @ObservedObject var vm: AppViewModel
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.87, green: 0.98, blue: 0.93), Color(red: 0.90, green: 0.95, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            backgroundOrbs

            VStack(spacing: 24) {
                mascotHeader

                VStack(spacing: 16) {
                    field(icon: "envelope.fill", placeholder: "Email", text: $email, isSecure: false)
                    field(icon: "lock.fill", placeholder: "Password", text: $password, isSecure: true)
                }

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                if vm.isLoading {
                    ProgressView()
                        .tint(Color(red: 0.22, green: 0.76, blue: 0.39))
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
                                colors: [Color(red: 0.20, green: 0.78, blue: 0.42), Color(red: 0.16, green: 0.62, blue: 0.36)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 6)
                }

                Button {
                    Task { await vm.signUp(email: email, password: password) }
                } label: {
                    Text("Create Account")
                        .font(.headline)
                        .foregroundStyle(Color(red: 0.16, green: 0.33, blue: 0.24))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color(red: 0.16, green: 0.33, blue: 0.24), lineWidth: 1)
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
                            colors: [Color(red: 0.35, green: 0.90, blue: 0.60), Color(red: 0.36, green: 0.74, blue: 1.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 86, height: 86)
                    .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)

                Image(systemName: "sparkles")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("SAT Quest")
                .font(.title.bold())
                .foregroundStyle(Color(red: 0.12, green: 0.22, blue: 0.18))

            Text("Level up your practice")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func field(icon: String, placeholder: String, text: Binding<String>, isSecure: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(red: 0.22, green: 0.76, blue: 0.39))
                .frame(width: 28)

            if isSecure {
                SecureField(placeholder, text: text)
                    .textInputAutocapitalization(.never)
            } else {
                TextField(placeholder, text: text)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.95))
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        )
    }

    private var backgroundOrbs: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.40, green: 0.80, blue: 1.0).opacity(0.25))
                .frame(width: 200, height: 200)
                .offset(x: 140, y: -220)

            Circle()
                .fill(Color(red: 0.30, green: 1.0, blue: 0.65).opacity(0.18))
                .frame(width: 240, height: 240)
                .offset(x: -160, y: 240)
        }
    }
}
