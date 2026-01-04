import SwiftUI
import StudentCore

struct PracticeFlowView: View {
    private let session: PracticeSession
    @StateObject private var vm: QuestionFeedViewModel
    @StateObject private var flowModel: PracticeFlowViewModel
    @State private var answers: [String: String] = [:]
    @State private var showingOverview = false
    @State private var returnToOverviewOnAnswer = false

    init(session: PracticeSession, sessionId: String, studentId: String) {
        self.session = session
        _vm = StateObject(wrappedValue: QuestionFeedViewModel(session: session))
        _flowModel = StateObject(wrappedValue: PracticeFlowViewModel(session: session, sessionId: sessionId, studentId: studentId))
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
