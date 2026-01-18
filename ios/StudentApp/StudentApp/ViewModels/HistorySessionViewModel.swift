import Foundation
import StudentCore

@MainActor
final class HistorySessionViewModel: ObservableObject, AttemptInsightProviding {
    @Published var sessionResult: SessionResult?
    @Published var isLoading = false
    @Published var errorMessage: String?

    let sessionId: String

    private let practiceService: SupabasePracticeService
    private let insightCache = AttemptInsightCache.shared

    init(sessionId: String, practiceService: SupabasePracticeService = SupabasePracticeService()) {
        self.sessionId = sessionId
        self.practiceService = practiceService
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            sessionResult = try await practiceService.fetchSessionResult(sessionId: sessionId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func attemptId(for questionId: String) -> String? {
        sessionResult?.questions.first(where: { $0.questionId == questionId })?.attemptId
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
}
