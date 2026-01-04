import Foundation
import StudentCore

@MainActor
final class AppViewModel: ObservableObject {
    @Published var user: AuthUser?
    @Published var session: PracticeSession?
    @Published var sessionId: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authService: AuthService
    private let practiceService: SupabasePracticeService

    init(authService: AuthService = AuthService(), practiceService: SupabasePracticeService = SupabasePracticeService()) {
        self.authService = authService
        self.practiceService = practiceService
        self.user = authService.currentUser()
        if let existingUser = self.user {
            isLoading = true
            Task {
                do {
                    try await loadSession(for: existingUser.id)
                } catch {
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
        }
    }

    func signIn(email: String, password: String) async {
        await authenticate { try await authService.signIn(email: email, password: password) }
    }

    func signUp(email: String, password: String) async {
        await authenticate { try await authService.signUp(email: email, password: password) }
    }

    func signOut() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await authService.signOut()
            user = nil
            session = nil
            sessionId = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func authenticate(_ action: () async throws -> AuthUser) async {
        isLoading = true
        errorMessage = nil
        do {
            let authedUser = try await action()
            user = authedUser
            try await loadSession(for: authedUser.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func loadSession(for studentId: String) async throws {
        let questions = try await practiceService.fetchQuestions(limit: 10)
        guard !questions.isEmpty else {
            errorMessage = "No questions available."
            return
        }
        let newSessionId = try await practiceService.createSession(studentId: studentId, totalQuestions: questions.count)
        session = PracticeSession(id: newSessionId, questions: questions)
        sessionId = newSessionId
    }
}
