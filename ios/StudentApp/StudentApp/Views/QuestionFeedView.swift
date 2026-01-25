import SwiftUI
import StudentCore

struct QuestionFeedView: View {
    let session: PracticeSession
    let analysisEnabled: Bool
    @ObservedObject var state: QuestionFeedState
    @ObservedObject var store: InMemoryAnswerStore
    let submission: AnswerSubmissionCoordinator
    @Binding var returnToOverviewOnAnswer: Bool
    let onBack: () -> Void
    let onShowOverview: () -> Void
    let onSubmissionError: (Error) -> Void

    @State private var perfTask: Task<Void, Never>?
    @State private var perfDirection = 1

    var body: some View {
        let total = session.questions.count

        ZStack {
            PracticeBackgroundView()

            QuestionFeedContainerView(
                session: session,
                analysisEnabled: analysisEnabled,
                state: state,
                store: store,
                submission: submission,
                returnToOverviewOnAnswer: $returnToOverviewOnAnswer,
                onBack: onBack,
                onShowOverview: onShowOverview,
                onSubmissionError: onSubmissionError
            )
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            startPerfAutoPaging(total: total)
        }
        .onDisappear {
            stopPerfAutoPaging()
            submission.cancelAll()
        }
    }

    // MARK: - Perf Harness

    private func startPerfAutoPaging(total: Int) {
        let config = PerfHarnessConfig.current
        guard config.isEnabled, perfTask == nil else { return }
        guard total > 1 else { return }

        perfTask = Task {
            let endTime = Date().addingTimeInterval(config.durationSeconds)
            while Date() < endTime, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(config.paceSeconds * 1_000_000_000))
                await MainActor.run {
                    guard total > 1 else { return }
                    state.setFocus(false)
                    let lastIndex = total - 1
                    if perfDirection > 0 {
                        if state.currentIndex >= lastIndex {
                            perfDirection = -1
                            state.jump(to: max(lastIndex - 1, 0), total: total)
                        } else {
                            state.advance(total: total)
                        }
                    } else {
                        if state.currentIndex <= 0 {
                            perfDirection = 1
                            state.jump(to: min(1, lastIndex), total: total)
                        } else {
                            state.retreat()
                        }
                    }
                }
            }
        }
    }

    private func stopPerfAutoPaging() {
        perfTask?.cancel()
        perfTask = nil
    }
}
