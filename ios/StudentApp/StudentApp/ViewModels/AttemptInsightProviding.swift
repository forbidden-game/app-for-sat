import Combine
import Foundation
import StudentCore

@MainActor
protocol AttemptInsightProviding: ObservableObject {
    func attemptId(for questionId: String) -> String?
    func setAttemptStepSelection(attemptId: String, selectedStepIndex: Int?, isUnknown: Bool) async throws
    func cachedAttemptInsight(attemptId: String) -> AttemptInsight?
    func fetchAttemptInsight(attemptId: String) async throws -> AttemptInsight?
}
