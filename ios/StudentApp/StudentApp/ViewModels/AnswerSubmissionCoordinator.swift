import Combine
import Foundation
import StudentCore

protocol AnswerSubmitting {
    func submitAnswer(question: Question, answer: String, allowCoach: Bool) async throws -> SubmitAttemptResult
}

enum SubmissionStatus: Equatable {
    case idle
    case submitting
    case failed(String)
}

@MainActor
final class AnswerSubmissionCoordinator: ObservableObject {
    private let submitter: AnswerSubmitting
    @Published private(set) var statusByQuestionId: [String: SubmissionStatus] = [:]

    private struct SubmissionState {
        var latestAnswer: String
        var task: Task<Void, Never>?
    }

    private var submissions: [String: SubmissionState] = [:]

    init(submitter: AnswerSubmitting) {
        self.submitter = submitter
    }

    func status(for questionId: String) -> SubmissionStatus {
        statusByQuestionId[questionId] ?? .idle
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
            statusByQuestionId[questionId] = .submitting
            if existing.task != nil { return }
        } else {
            submissions[questionId] = SubmissionState(latestAnswer: answer, task: nil)
            statusByQuestionId[questionId] = .submitting
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
                        await MainActor.run {
                            self.statusByQuestionId[questionId] = .failed(error.localizedDescription)
                            onFailure(error)
                        }
                    }
                    break
                }

                let shouldContinue: Bool = await MainActor.run {
                    guard let latest = self.submissions[questionId]?.latestAnswer else { return false }
                    return latest != currentAnswer
                }

                await MainActor.run {
                    self.statusByQuestionId[questionId] = shouldContinue ? .submitting : .idle
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
        statusByQuestionId.removeAll()
    }
}
