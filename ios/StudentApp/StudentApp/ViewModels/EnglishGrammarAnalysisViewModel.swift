import Foundation
import StudentCore

@MainActor
final class EnglishGrammarAnalysisViewModel: ObservableObject {
    enum LoadState {
        case idle
        case loading(status: EnglishGrammarAnalysisStatus)
        case ready(EnglishGrammarAnalysis)
        case failed(String)
    }

    @Published private(set) var state: LoadState = .idle

    private let service: SupabasePracticeService
    private var pollTask: Task<Void, Never>?
    private var didRequest = false

    init(service: SupabasePracticeService = SupabasePracticeService()) {
        self.service = service
    }

    func start(questionId: String) {
        guard !didRequest else { return }
        didRequest = true
        state = .loading(status: .queued)

        pollTask?.cancel()
        pollTask = Task {
            await requestAnalysis(questionId: questionId)
            await pollForUpdates(questionId: questionId)
        }
    }

    func retry(questionId: String) {
        didRequest = false
        start(questionId: questionId)
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func requestAnalysis(questionId: String) async {
        do {
            let record = try await service.requestEnglishGrammarAnalysis(questionId: questionId)
            state = .loading(status: record.status)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func pollForUpdates(questionId: String) async {
        let delays: [UInt64] = [0, 1, 1, 2, 3, 5, 5, 8, 8, 12]

        for delay in delays {
            if Task.isCancelled { return }
            if case .failed = state { return }
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
            }

            guard let record = try? await service.fetchEnglishGrammarAnalysis(questionId: questionId) else {
                continue
            }

            switch record.status {
            case .done:
                if let analysis = record.analysis {
                    state = .ready(analysis)
                    return
                }
            case .error:
                state = .failed(record.error ?? "Analysis failed")
                return
            case .queued, .running:
                state = .loading(status: record.status)
            }
        }
    }
}
