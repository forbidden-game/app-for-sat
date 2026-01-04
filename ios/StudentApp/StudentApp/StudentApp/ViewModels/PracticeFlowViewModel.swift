import Combine
import Foundation
import StudentCore

@MainActor
final class PracticeFlowViewModel: ObservableObject {
    @Published var correctByQuestion: [String: Bool] = [:]
    @Published var submissionError: String?
    @Published var isSubmitting = false

    let session: PracticeSession
    let sessionId: String
    let studentId: String

    private let practiceService: SupabasePracticeService
    private var pendingAnswers: [String: String] = [:]

    init(session: PracticeSession, sessionId: String, studentId: String, practiceService: SupabasePracticeService = SupabasePracticeService()) {
        self.session = session
        self.sessionId = sessionId
        self.studentId = studentId
        self.practiceService = practiceService
    }

    func submitAnswer(question: Question, answer: String) {
        pendingAnswers[question.id] = answer
        Task {
            do {
                let isCorrect = try await practiceService.submitAttempt(
                    question: question,
                    answer: answer,
                    sessionId: sessionId,
                    studentId: studentId
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
                            sessionId: sessionId,
                            studentId: studentId
                        )
                        correctByQuestion[question.id] = isCorrect
                    }
                }
                pendingAnswers.removeAll()
                let correctCount = correctByQuestion.values.filter { $0 }.count
                try await practiceService.updateSession(
                    sessionId: sessionId,
                    totalQuestions: session.questions.count,
                    correctCount: correctCount
                )
            } catch {
                submissionError = error.localizedDescription
            }
        }
    }
}
