import Combine
import Foundation
import StudentCore

enum PracticeFlowState {
    case practicing
    case overview
    case result(SessionResult)
    case questionDetail(QuestionResult)
}

@MainActor
final class PracticeFlowViewModel: ObservableObject {
    @Published var correctByQuestion: [String: Bool] = [:]
    @Published var submissionError: String?
    @Published var isSubmitting = false
    @Published var flowState: PracticeFlowState = .practicing
    @Published var sessionResult: SessionResult?

    let session: PracticeSession
    let sessionId: String

    private let practiceService: SupabasePracticeService
    private var pendingAnswers: [String: String] = [:]

    init(session: PracticeSession, sessionId: String, practiceService: SupabasePracticeService = SupabasePracticeService()) {
        self.session = session
        self.sessionId = sessionId
        self.practiceService = practiceService
    }

    func submitAnswer(question: Question, answer: String) {
        pendingAnswers[question.id] = answer
        Task {
            do {
                let isCorrect = try await practiceService.submitAttempt(
                    question: question,
                    answer: answer,
                    sessionId: sessionId
                )
                correctByQuestion[question.id] = isCorrect
                pendingAnswers.removeValue(forKey: question.id)
            } catch {
                submissionError = error.localizedDescription
            }
        }
    }

    func finalizeSession() {
        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            do {
                for (questionId, answer) in pendingAnswers {
                    if let question = session.questions.first(where: { $0.id == questionId }) {
                        let isCorrect = try await practiceService.submitAttempt(
                            question: question,
                            answer: answer,
                            sessionId: sessionId
                        )
                        correctByQuestion[question.id] = isCorrect
                    }
                }
                pendingAnswers.removeAll()

                let result = try await practiceService.fetchSessionResult(sessionId: sessionId)
                sessionResult = result
                flowState = .result(result)
            } catch {
                submissionError = error.localizedDescription
            }
        }
    }

    func showQuestionDetail(_ question: QuestionResult) {
        flowState = .questionDetail(question)
    }

    func backToResult() {
        if let result = sessionResult {
            flowState = .result(result)
        }
    }
}
