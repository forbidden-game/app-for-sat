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
    private let insightCache = AttemptInsightCache.shared
    private var insightPrefetchTasks: [String: Task<Void, Never>] = [:]
    private var attemptIdsByQuestion: [String: String] = [:]
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
        attemptIdsByQuestion[question.id] = result.attemptId
        pendingAnswers.removeValue(forKey: question.id)

        if result.isCorrect == false {
            prefetchAttemptInsight(attemptId: result.attemptId)
            if allowCoach {
                coachAttempt = CoachAttemptContext(id: result.attemptId, questionId: question.id, answer: answer)
            }
        }

        return result
    }

    func attemptId(for questionId: String) -> String? {
        if let attemptId = attemptIdsByQuestion[questionId] {
            return attemptId
        }
        if let result = sessionResult {
            return result.questions.first(where: { $0.questionId == questionId })?.attemptId
        }
        return nil
    }

    func setAttemptStepSelection(attemptId: String, selectedStepIndex: Int?, isUnknown: Bool) async throws {
        try await practiceService.setAttemptStepSelection(
            attemptId: attemptId,
            selectedStepIndex: selectedStepIndex,
            isUnknown: isUnknown
        )
    }

    func cachedAttemptInsight(attemptId: String) -> AttemptInsight? {
        insightCache.load(attemptId: attemptId)
    }

    func fetchAttemptInsight(attemptId: String) async throws -> AttemptInsight? {
        let insight = try await practiceService.fetchAttemptInsight(attemptId: attemptId)
        if let insight {
            insightCache.save(insight)
        }
        return insight
    }

    func prefetchAttemptInsight(attemptId: String) {
        if insightCache.load(attemptId: attemptId) != nil { return }
        if insightPrefetchTasks[attemptId] != nil { return }

        let task = Task { [weak self] in
            guard let self else { return }
            defer { self.insightPrefetchTasks[attemptId] = nil }
            for _ in 0..<12 {
                if Task.isCancelled { return }
                if let insight = try? await self.fetchAttemptInsight(attemptId: attemptId), insight != nil {
                    return
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }

        insightPrefetchTasks[attemptId] = task
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
                        attemptIdsByQuestion[question.id] = result.attemptId
                    }
                }
                pendingAnswers.removeAll()

                let result = try await practiceService.fetchSessionResult(sessionId: sessionId)
                for question in result.questions {
                    if let attemptId = question.attemptId {
                        attemptIdsByQuestion[question.questionId] = attemptId
                    }
                }
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
