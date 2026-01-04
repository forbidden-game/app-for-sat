import SwiftUI
import StudentCore

struct QuestionFeedView: View {
    @StateObject var vm: QuestionFeedViewModel

    var body: some View {
        let question = vm.session.questions[vm.currentIndex]
        VStack(alignment: .leading, spacing: 16) {
            Text(question.stem).font(.title2)
            Button("Next") { vm.advance() }
        }
        .padding()
    }
}
