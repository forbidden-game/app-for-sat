import Combine
import Foundation
import StudentCore

@MainActor
final class AppViewModel: ObservableObject {
    @Published var user: AuthUser?
    @Published var session: PracticeSession?
    @Published var sessionId: String?
    @Published var selectedBank: QuestionBank?
    @Published var banks: [QuestionBank] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authService: AuthService
    private let practiceService: SupabasePracticeService

    init(authService: AuthService = AuthService(), practiceService: SupabasePracticeService = SupabasePracticeService()) {
        self.authService = authService
        self.practiceService = practiceService
        self.user = authService.currentUser()
        if user != nil {
            Task {
                await loadBanks()
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
            selectedBank = nil
            banks = []
        } catch {
            errorMessage = UserFacingError.message(error)
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
            await loadBanks()
        } catch {
            errorMessage = UserFacingError.message(error)
        }
        isLoading = false
    }

    func loadBanks() async {
        isLoading = true
        errorMessage = nil
        do {
            banks = try await practiceService.fetchQuestionBanks()
        } catch {
            errorMessage = UserFacingError.message(error)
        }
        isLoading = false
    }

    func startSession(for bank: QuestionBank) async {
        isLoading = true
        errorMessage = nil
        selectedBank = bank
        session = nil
        sessionId = nil
        do {
            let newSession = try await practiceService.startPracticeSession(bankSlug: bank.slug)
            session = newSession
            sessionId = newSession.id
        } catch {
            errorMessage = UserFacingError.message(error)
            selectedBank = nil
        }
        isLoading = false
    }
}
