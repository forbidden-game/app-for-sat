import Combine
import Foundation
import StudentCore

enum PracticeFlowState {
    case practicing
    case overview
    case result(SessionResult)
    case questionDetail(QuestionResult)
}

struct CoachAttemptContext: Identifiable {
    let id: String // attemptId
    let questionId: String
    let answer: String
}

@MainActor
final class PracticeFlowViewModel: ObservableObject {
    @Published var correctByQuestion: [String: Bool] = [:]
    @Published var submissionError: String?
    @Published var isSubmitting = false
    @Published var flowState: PracticeFlowState = .practicing
    @Published var sessionResult: SessionResult?
    @Published var coachAttempt: CoachAttemptContext?

    let session: PracticeSession
    let sessionId: String

    private let practiceService: SupabasePracticeService
    private var pendingAnswers: [String: String] = [:]

    init(session: PracticeSession, sessionId: String, practiceService: SupabasePracticeService = SupabasePracticeService()) {
        self.session = session
        self.sessionId = sessionId
        self.practiceService = practiceService
    }

    func submitAnswer(question: Question, answer: String, allowCoach: Bool) async throws -> SubmitAttemptResult {
        pendingAnswers[question.id] = answer

        let result = try await practiceService.submitAttempt(
            question: question,
            answer: answer,
            sessionId: sessionId
        )

        correctByQuestion[question.id] = result.isCorrect
        pendingAnswers.removeValue(forKey: question.id)

        if allowCoach, result.isCorrect == false {
            coachAttempt = CoachAttemptContext(id: result.attemptId, questionId: question.id, answer: answer)
        }

        return result
    }

    func setAttemptStepSelection(attemptId: String, selectedStepIndex: Int?, isUnknown: Bool) async throws {
        try await practiceService.setAttemptStepSelection(
            attemptId: attemptId,
            selectedStepIndex: selectedStepIndex,
            isUnknown: isUnknown
        )
    }

    func fetchAttemptInsight(attemptId: String) async throws -> AttemptInsight? {
        try await practiceService.fetchAttemptInsight(attemptId: attemptId)
    }

    func finalizeSession() {
        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            do {
                for (questionId, answer) in pendingAnswers {
                    if let question = session.questions.first(where: { $0.id == questionId }) {
                        let result = try await practiceService.submitAttempt(
                            question: question,
                            answer: answer,
                            sessionId: sessionId
                        )
                        correctByQuestion[question.id] = result.isCorrect
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
