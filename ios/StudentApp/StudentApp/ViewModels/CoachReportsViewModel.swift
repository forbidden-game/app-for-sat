import Combine
import Foundation
import StudentCore

@MainActor
final class CoachReportsViewModel: ObservableObject {
    enum ReportKind: String, CaseIterable, Identifiable {
        case weekly
        case monthly

        var id: String { rawValue }

        var title: String {
            switch self {
            case .weekly:
                return "周报"
            case .monthly:
                return "月报"
            }
        }
    }

    @Published var selectedKind: ReportKind = .weekly
    @Published var reports: [StudentReport] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let studentId: String
    private let service: SupabaseCoachService

    init(studentId: String, service: SupabaseCoachService = SupabaseCoachService()) {
        self.studentId = studentId
        self.service = service
    }

    func load() async {
        await load(kind: selectedKind)
    }

    func refresh() async {
        await load(kind: selectedKind)
    }

    func select(_ kind: ReportKind) async {
        guard kind != selectedKind else { return }
        selectedKind = kind
        await load(kind: kind)
    }

    private func load(kind: ReportKind) async {
        isLoading = true
        errorMessage = nil
        do {
            reports = try await service.fetchStudentReports(studentId: studentId, periodKind: kind.rawValue, limit: 4)
        } catch {
            errorMessage = UserFacingError.message(error)
            reports = []
        }
        isLoading = false
    }
}
