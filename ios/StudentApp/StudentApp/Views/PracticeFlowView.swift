import SwiftUI
import StudentCore

struct PracticeFlowView: View {
    private let session: PracticeSession
    private let studentId: String
    @StateObject private var vm: QuestionFeedViewModel
    @StateObject private var flowModel: PracticeFlowViewModel
    @State private var answers: [String: String] = [:]
    @State private var returnToOverviewOnAnswer = false
    let headerTitle: String?
    let onExit: () -> Void

    init(session: PracticeSession, sessionId: String, studentId: String, headerTitle: String?, onExit: @escaping () -> Void) {
        self.session = session
        self.studentId = studentId
        _vm = StateObject(wrappedValue: QuestionFeedViewModel(session: session))
        _flowModel = StateObject(wrappedValue: PracticeFlowViewModel(session: session, sessionId: sessionId))
        self.headerTitle = headerTitle
        self.onExit = onExit
    }

    var body: some View {
        switch flowModel.flowState {
        case .practicing:
            QuestionFeedView(
                studentId: studentId,
                vm: vm,
                answers: $answers,
                returnToOverviewOnAnswer: $returnToOverviewOnAnswer,
                headerTitle: headerTitle,
                flowModel: flowModel,
                onBack: onExit,
                onShowOverview: {
                    flowModel.flowState = .overview
                }
            )

        case .overview:
            SessionOverviewView(
                session: session,
                answers: answers,
                isSubmitting: flowModel.isSubmitting,
                submissionError: flowModel.submissionError,
                onSelectQuestion: { index in
                    returnToOverviewOnAnswer = true
                    vm.jump(to: index)
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
}
