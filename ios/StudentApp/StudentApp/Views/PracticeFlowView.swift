import SwiftUI
import StudentCore

struct PracticeFlowView: View {
    private let session: PracticeSession
    private let studentId: String
    @StateObject private var feedState: QuestionFeedState
    @StateObject private var answerStore: InMemoryAnswerStore
    @StateObject private var flowModel: PracticeFlowViewModel
    @State private var returnToOverviewOnAnswer = false
    let onExit: () -> Void
    private let submissionCoordinator: AnswerSubmissionCoordinator

    init(session: PracticeSession, sessionId: String, studentId: String, onExit: @escaping () -> Void) {
        self.session = session
        self.studentId = studentId
        let flow = PracticeFlowViewModel(session: session, sessionId: sessionId)
        _flowModel = StateObject(wrappedValue: flow)
        _feedState = StateObject(wrappedValue: QuestionFeedState(initialIndex: 0))
        _answerStore = StateObject(wrappedValue: InMemoryAnswerStore())
        submissionCoordinator = AnswerSubmissionCoordinator(submitter: flow)
        self.onExit = onExit
    }

    var body: some View {
        Group {
            switch flowModel.flowState {
            case .practicing:
                QuestionFeedView(
                    session: session,
                    state: feedState,
                    store: answerStore,
                    submission: submissionCoordinator,
                    returnToOverviewOnAnswer: $returnToOverviewOnAnswer,
                    onBack: onExit,
                    onShowOverview: {
                        flowModel.flowState = .overview
                    },
                    onSubmissionError: { error in
                        flowModel.submissionError = error.localizedDescription
                    }
                )

            case .overview:
                SessionOverviewView(
                    session: session,
                    answers: answerStore.stringAnswers(),
                    isSubmitting: flowModel.isSubmitting,
                    submissionError: flowModel.submissionError,
                    pendingCount: flowModel.pendingCount,
                    onSelectQuestion: { index in
                        returnToOverviewOnAnswer = true
                        feedState.jump(to: index, total: session.questions.count)
                        flowModel.flowState = .practicing
                    },
                    onSubmit: {
                        flowModel.finalizeSession()
                    }
                )

            case .result(let result):
                SessionResultView(
                    result: result,
                    onSelectQuestion: { question in
                        flowModel.showQuestionDetail(question)
                    },
                    onDismiss: onExit
                )

            case .questionDetail(let question):
                QuestionDetailView(
                    question: question,
                    studentId: studentId,
                    flowModel: flowModel,
                    onBack: {
                        flowModel.backToResult()
                    }
                )
            }
        }
        .task {
            await flowModel.flushPendingAnswers()
        }
    }
}
