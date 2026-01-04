import SwiftUI
import StudentCore

struct PracticeFlowView: View {
    private let session: PracticeSession
    @StateObject private var vm: QuestionFeedViewModel
    @State private var answers: [String: String] = [:]
    @State private var showingOverview = false
    @State private var returnToOverviewOnAnswer = false

    init(session: PracticeSession) {
        self.session = session
        _vm = StateObject(wrappedValue: QuestionFeedViewModel(session: session))
    }

    var body: some View {
        if showingOverview {
            SessionOverviewView(
                session: session,
                answers: answers,
                onSelectQuestion: { index in
                    returnToOverviewOnAnswer = true
                    vm.jump(to: index)
                    showingOverview = false
                },
                onSubmit: {
                    // Submission wiring will be added later.
                }
            )
        } else {
            QuestionFeedView(
                vm: vm,
                answers: $answers,
                returnToOverviewOnAnswer: $returnToOverviewOnAnswer,
                onShowOverview: {
                    showingOverview = true
                }
            )
        }
    }
}
