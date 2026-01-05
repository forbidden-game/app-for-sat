import Combine
import Foundation
import StudentCore

@MainActor
final class AppViewModel: ObservableObject {
    @Published var user: AuthUser?
    @Published var session: PracticeSession?
    @Published var sessionId: String?
    @Published var selectedBank: QuestionBank?
    @Published var banks: [QuestionBank] = QuestionBank.samples
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authService: AuthService
    private let practiceService: SupabasePracticeService

    init(authService: AuthService = AuthService(), practiceService: SupabasePracticeService = SupabasePracticeService()) {
        self.authService = authService
        self.practiceService = practiceService
        self.user = authService.currentUser()
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
            selectedBank = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exitSession() {
        session = nil
        sessionId = nil
        selectedBank = nil
        errorMessage = nil
    }

    private func authenticate(_ action: () async throws -> AuthUser) async {
        isLoading = true
        errorMessage = nil
        do {
            let authedUser = try await action()
            user = authedUser
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func startSession(for bank: QuestionBank) async {
        guard let studentId = user?.id else { return }
        isLoading = true
        errorMessage = nil
        selectedBank = bank
        session = nil
        sessionId = nil
        do {
            try await loadSession(for: studentId, limit: bank.questionLimit)
            if sessionId == nil {
                selectedBank = nil
            }
        } catch {
            errorMessage = error.localizedDescription
            selectedBank = nil
        }
        isLoading = false
    }

    private func loadSession(for studentId: String, limit: Int) async throws {
        let questions = try await practiceService.fetchQuestions(limit: limit)
        guard !questions.isEmpty else {
            errorMessage = "No questions available."
            return
        }
        let newSessionId = try await practiceService.createSession(studentId: studentId, totalQuestions: questions.count)
        session = PracticeSession(id: newSessionId, questions: questions)
        sessionId = newSessionId
    }
}
