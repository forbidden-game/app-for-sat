import SwiftUI
import StudentCore

struct QuestionFeedContainerView: UIViewControllerRepresentable {
    let session: PracticeSession
    let analysisEnabled: Bool
    @ObservedObject var state: QuestionFeedState
    @ObservedObject var store: InMemoryAnswerStore
    let submission: AnswerSubmissionCoordinator
    @Binding var returnToOverviewOnAnswer: Bool
    let onBack: () -> Void
    let onShowOverview: () -> Void
    let onSubmissionError: (Error) -> Void

    func makeUIViewController(context: Context) -> QuestionFeedPagingController {
        QuestionFeedPagingController(
            session: session,
            state: state,
            store: store,
            submission: submission,
            analysisEnabled: analysisEnabled,
            returnToOverviewOnAnswer: $returnToOverviewOnAnswer,
            onBack: onBack,
            onShowOverview: onShowOverview,
            onSubmissionError: onSubmissionError
        )
    }

    func updateUIViewController(_ controller: QuestionFeedPagingController, context: Context) {
        controller.update(
            session: session,
            state: state,
            store: store,
            submission: submission,
            analysisEnabled: analysisEnabled,
            returnToOverviewOnAnswer: $returnToOverviewOnAnswer,
            onBack: onBack,
            onShowOverview: onShowOverview,
            onSubmissionError: onSubmissionError
        )
    }
}
