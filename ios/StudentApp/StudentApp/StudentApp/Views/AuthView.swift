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

            VStack(spacing: 20) {
                Text("Welcome Back")
                    .font(.title.bold())

                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                if vm.isLoading {
                    ProgressView()
                }

                Button {
                    Task { await vm.signIn(email: email, password: password) }
                } label: {
                    Text("Sign In")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.22, green: 0.76, blue: 0.39))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button {
                    Task { await vm.signUp(email: email, password: password) }
                } label: {
                    Text("Create Account")
                        .font(.headline)
                        .foregroundStyle(Color(red: 0.16, green: 0.33, blue: 0.24))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color(red: 0.16, green: 0.33, blue: 0.24), lineWidth: 1)
                        )
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
        }
    }
}
