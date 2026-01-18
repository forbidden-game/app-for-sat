import Combine
import Foundation
import StudentCore

@MainActor
final class PracticeHistoryViewModel: ObservableObject {
    enum RangeFilter: String, CaseIterable, Identifiable {
        case last7
        case last30
        case last90
        case all

        var id: String { rawValue }

        var title: String {
            switch self {
            case .last7: return "近7天"
            case .last30: return "近30天"
            case .last90: return "近90天"
            case .all: return "全部"
            }
        }

        func startDate(from now: Date = Date()) -> Date? {
            let calendar = Calendar.current
            switch self {
            case .last7:
                return calendar.date(byAdding: .day, value: -7, to: now)
            case .last30:
                return calendar.date(byAdding: .day, value: -30, to: now)
            case .last90:
                return calendar.date(byAdding: .day, value: -90, to: now)
            case .all:
                return nil
            }
        }
    }

    @Published var items: [SessionHistoryItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedRange: RangeFilter = .last30
    @Published var selectedBankId: String?

    private let practiceService: SupabasePracticeService

    init(practiceService: SupabasePracticeService = SupabasePracticeService()) {
        self.practiceService = practiceService
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let start = selectedRange.startDate()
            items = try await practiceService.fetchSessionHistory(
                start: start,
                end: nil,
                bankId: selectedBankId,
                limit: 100,
                offset: 0
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        await load()
    }
}
