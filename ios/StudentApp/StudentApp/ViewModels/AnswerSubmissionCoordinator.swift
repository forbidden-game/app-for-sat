import Foundation
import StudentCore

protocol AnswerSubmitting {
    func submitAnswer(question: Question, answer: String, allowCoach: Bool) async throws -> SubmitAttemptResult
}

@MainActor
final class AnswerSubmissionCoordinator {
    private let submitter: AnswerSubmitting
    private var tasks: [String: Task<Void, Never>] = [:]

    init(submitter: AnswerSubmitting) {
        self.submitter = submitter
    }

    func submit(
        question: Question,
        answer: String,
        questionId: String,
        onSuccess: @escaping (SubmitAttemptResult) -> Void,
        onFailure: @escaping (Error) -> Void
    ) {
        if let existing = tasks[questionId], !existing.isCancelled {
            return
        }

        let task = Task { [weak self] in
            defer { self?.tasks[questionId] = nil }
            do {
                let result = try await self?.submitter.submitAnswer(
                    question: question,
                    answer: answer,
                    allowCoach: false
                )
                if let result {
                    await MainActor.run {
                        onSuccess(result)
                    }
                }
            } catch {
                await MainActor.run {
                    onFailure(error)
                }
            }
        }

        tasks[questionId] = task
    }

    func cancelAll() {
        for (_, task) in tasks {
            task.cancel()
        }
        tasks.removeAll()
    }
}
