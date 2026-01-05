import SwiftUI
import StudentCore

struct PracticeFlowView: View {
    private let session: PracticeSession
    @StateObject private var vm: QuestionFeedViewModel
    @StateObject private var flowModel: PracticeFlowViewModel
    @State private var answers: [String: String] = [:]
    @State private var showingOverview = false
    @State private var returnToOverviewOnAnswer = false
    let headerTitle: String?
    let onExit: () -> Void

    init(session: PracticeSession, sessionId: String, headerTitle: String?, onExit: @escaping () -> Void) {
        self.session = session
        _vm = StateObject(wrappedValue: QuestionFeedViewModel(session: session))
        _flowModel = StateObject(wrappedValue: PracticeFlowViewModel(session: session, sessionId: sessionId))
        self.headerTitle = headerTitle
        self.onExit = onExit
    }

    var body: some View {
        if showingOverview {
            SessionOverviewView(
                session: session,
                answers: answers,
                isSubmitting: flowModel.isSubmitting,
                submissionError: flowModel.submissionError,
                onSelectQuestion: { index in
                    returnToOverviewOnAnswer = true
                    vm.jump(to: index)
                    showingOverview = false
                },
                onSubmit: {
                    flowModel.finalizeSession()
                }
            )
        } else {
            QuestionFeedView(
                vm: vm,
                answers: $answers,
                returnToOverviewOnAnswer: $returnToOverviewOnAnswer,
                headerTitle: headerTitle,
                onBack: onExit,
                onShowOverview: {
                    showingOverview = true
                },
                onAnswer: { question, answer in
                    flowModel.submitAnswer(question: question, answer: answer)
                }
            )
        }
    }
}
