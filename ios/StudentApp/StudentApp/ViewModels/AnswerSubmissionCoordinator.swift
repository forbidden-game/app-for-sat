import Foundation
import StudentCore

protocol AnswerSubmitting {
    func submitAnswer(question: Question, answer: String, allowCoach: Bool) async throws -> SubmitAttemptResult
}

@MainActor
final class AnswerSubmissionCoordinator {
    private let submitter: AnswerSubmitting
    private struct SubmissionState {
        var latestAnswer: String
        var task: Task<Void, Never>?
    }

    private var submissions: [String: SubmissionState] = [:]

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
        if var existing = submissions[questionId] {
            existing.latestAnswer = answer
            submissions[questionId] = existing
            if existing.task != nil { return }
        } else {
            submissions[questionId] = SubmissionState(latestAnswer: answer, task: nil)
        }

        let task = Task { [weak self] in
            while let self, !Task.isCancelled {
                let currentAnswer: String? = await MainActor.run {
                    self.submissions[questionId]?.latestAnswer
                }
                guard let currentAnswer else { break }

                do {
                    let result = try await self.submitter.submitAnswer(
                        question: question,
                        answer: currentAnswer,
                        allowCoach: false
                    )
                    await MainActor.run { onSuccess(result) }
                } catch {
                    if !Task.isCancelled {
                        await MainActor.run { onFailure(error) }
                    }
                    break
                }

                let shouldContinue: Bool = await MainActor.run {
                    guard let latest = self.submissions[questionId]?.latestAnswer else { return false }
                    return latest != currentAnswer
                }

                if !shouldContinue { break }
            }

            await MainActor.run { [weak self] in
                self?.submissions[questionId]?.task = nil
            }
        }

        submissions[questionId]?.task = task
    }

    func cancelAll() {
        for (_, submission) in submissions {
            submission.task?.cancel()
        }
        submissions.removeAll()
    }
}
