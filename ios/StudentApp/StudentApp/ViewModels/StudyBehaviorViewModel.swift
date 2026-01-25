import Foundation
import StudentCore

@MainActor
final class StudyBehaviorViewModel: ObservableObject {
    @Published var behavior: StudyBehavior?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let practiceService: SupabasePracticeService

    init(practiceService: SupabasePracticeService = SupabasePracticeService()) {
        self.practiceService = practiceService
    }

    func load(windowDays: Int = 7) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            behavior = try await practiceService.fetchStudyBehavior(windowDays: windowDays, historyWeeks: 8)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
