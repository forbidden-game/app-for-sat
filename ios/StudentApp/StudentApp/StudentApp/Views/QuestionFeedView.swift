import SwiftUI
import StudentCore

struct QuestionFeedView: View {
    @StateObject var vm: QuestionFeedViewModel
    @State private var selectedOption: String?
    @State private var freeResponse: String = ""

    var body: some View {
        let question = vm.session.questions[vm.currentIndex]
        VStack(alignment: .leading, spacing: 20) {
            Text(question.stem)
                .font(.title2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let options = question.options, !options.isEmpty {
                VStack(spacing: 12) {
                    ForEach(options, id: \.label) { option in
                        Button {
                            selectedOption = option.label
                        } label: {
                            HStack {
                                Text("\(option.label). \(option.content)")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding()
                            .background(selectedOption == option.label ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                TextField("Enter your answer", text: $freeResponse)
                    .textFieldStyle(.roundedBorder)
            }

            Spacer()
            Text("Swipe up/down to change question")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    if value.translation.height < -40 {
                        selectedOption = nil
                        freeResponse = ""
                        vm.advance()
                    } else if value.translation.height > 40 {
                        selectedOption = nil
                        freeResponse = ""
                        vm.retreat()
                    }
                }
        )
    }
}
