import SwiftUI
import StudentCore

struct QuestionFeedContainerView: UIViewControllerRepresentable {
    let session: PracticeSession
    @ObservedObject var state: QuestionFeedState
    @ObservedObject var store: InMemoryAnswerStore
    let submission: AnswerSubmissionCoordinator
    @Binding var returnToOverviewOnAnswer: Bool
    let headerTitle: String?
    let onBack: () -> Void
    let onShowOverview: () -> Void
    let onSubmissionError: (Error) -> Void

    func makeUIViewController(context: Context) -> QuestionFeedPagingController {
        QuestionFeedPagingController(
            session: session,
            state: state,
            store: store,
            submission: submission,
            returnToOverviewOnAnswer: $returnToOverviewOnAnswer,
            headerTitle: headerTitle,
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
            returnToOverviewOnAnswer: $returnToOverviewOnAnswer,
            headerTitle: headerTitle,
            onBack: onBack,
            onShowOverview: onShowOverview,
            onSubmissionError: onSubmissionError
        )
    }
}
