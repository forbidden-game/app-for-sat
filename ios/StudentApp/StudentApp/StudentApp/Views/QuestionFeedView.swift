import SwiftUI
import StudentCore

struct QuestionFeedView: View {
    @StateObject var vm: QuestionFeedViewModel
    @Binding var answers: [String: String]
    @Binding var returnToOverviewOnAnswer: Bool
    let onShowOverview: () -> Void

    @State private var selectedOption: String?
    @State private var freeResponse: String = ""
    @State private var pendingAutoAdvance: DispatchWorkItem?
    @FocusState private var isInputFocused: Bool

    private let swipeThreshold: CGFloat = 30

    var body: some View {
        let question = vm.session.questions[vm.currentIndex]
        let total = vm.session.questions.count
        let progress = total > 0 ? Double(vm.currentIndex + 1) / Double(total) : 0

        ZStack {
            LinearGradient(
                colors: [Color(red: 0.87, green: 0.98, blue: 0.93), Color(red: 0.90, green: 0.95, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                header(progress: progress, index: vm.currentIndex + 1, total: total)

                questionCard(text: question.stem)

                if let options = question.options, !options.isEmpty {
                    optionsGrid(options)
                } else {
                    freeResponseField()
                }

                Spacer()

                Text("Swipe up/down to change question")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 12)
                .onEnded { value in
                    handleSwipe(value)
                }
        )
        .onAppear {
            loadAnswer(for: question)
        }
        .onChange(of: vm.currentIndex) { _, _ in
            loadAnswer(for: vm.session.questions[vm.currentIndex])
        }
        .onChange(of: freeResponse) { _, newValue in
            scheduleAutoAdvanceIfNeeded(with: newValue)
        }
    }

    private func header(progress: Double, index: Int, total: Int) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text("Practice")
                    .font(.headline)
                Spacer()
                Text("\(index)/\(total)")
                    .font(.subheadline)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.white.opacity(0.9))
                    .clipShape(Capsule())
            }

            ProgressView(value: progress)
                .tint(Color(red: 0.22, green: 0.76, blue: 0.39))
        }
    }

    private func questionCard(text: String) -> some View {
        Text(text)
            .font(.title2.bold())
            .foregroundStyle(Color(red: 0.1, green: 0.2, blue: 0.15))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
            )
    }

    private func optionsGrid(_ options: [QuestionOption]) -> some View {
        VStack(spacing: 12) {
            ForEach(options, id: \.label) { option in
                optionButton(option)
            }
        }
    }

    private func optionButton(_ option: QuestionOption) -> some View {
        let isSelected = selectedOption == option.label
        return Button {
            selectedOption = option.label
            recordAnswer(option.label)
            advanceAfterAnswer()
        } label: {
            HStack(spacing: 12) {
                Text(option.label)
                    .font(.headline)
                    .foregroundStyle(isSelected ? Color.white : Color(red: 0.16, green: 0.33, blue: 0.24))
                    .frame(width: 36, height: 36)
                    .background(isSelected ? Color(red: 0.22, green: 0.76, blue: 0.39) : Color(red: 0.90, green: 0.97, blue: 0.92))
                    .clipShape(Circle())

                Text(option.content)
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.12, green: 0.2, blue: 0.16))

                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color(red: 0.90, green: 1.0, blue: 0.93) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color(red: 0.22, green: 0.76, blue: 0.39) : Color.clear, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func freeResponseField() -> some View {
        HStack(spacing: 12) {
            Image(systemName: "pencil.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color(red: 0.22, green: 0.76, blue: 0.39))

            TextField("Type your answer", text: $freeResponse)
                .focused($isInputFocused)
                .textInputAutocapitalization(.never)
                .keyboardType(.numbersAndPunctuation)
                .submitLabel(.done)
                .onSubmit {
                    commitFreeResponse()
                }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 5)
        )
    }

    private func scheduleAutoAdvanceIfNeeded(with newValue: String) {
        pendingAutoAdvance?.cancel()
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let workItem = DispatchWorkItem {
            commitFreeResponse()
        }
        pendingAutoAdvance = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: workItem)
    }

    private func commitFreeResponse() {
        let trimmed = freeResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        pendingAutoAdvance?.cancel()
        recordAnswer(trimmed)
        isInputFocused = false
        advanceAfterAnswer()
    }

    private func recordAnswer(_ value: String) {
        let question = vm.session.questions[vm.currentIndex]
        answers[question.id] = value
    }

    private func advanceAfterAnswer() {
        resetInputs()
        let isLast = vm.currentIndex == vm.session.questions.count - 1
        if returnToOverviewOnAnswer || isLast {
            returnToOverviewOnAnswer = false
            onShowOverview()
        } else {
            vm.advance()
        }
    }

    private func header(progress: Double, index: Int, total: Int) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text("Practice")
                    .font(.headline)
                Spacer()
                Text("\(index)/\(total)")
                    .font(.subheadline)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.white.opacity(0.9))
                    .clipShape(Capsule())
            }

            ProgressView(value: progress)
                .tint(Color(red: 0.22, green: 0.76, blue: 0.39))
        }
    }

    private func questionCard(text: String) -> some View {
        Text(text)
            .font(.title2.bold())
            .foregroundStyle(Color(red: 0.1, green: 0.2, blue: 0.15))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
            )
    }

    private func optionsGrid(_ options: [QuestionOption]) -> some View {
        VStack(spacing: 12) {
            ForEach(options, id: \.label) { option in
                optionButton(option)
            }
        }
    }

    private func optionButton(_ option: QuestionOption) -> some View {
        let isSelected = selectedOption == option.label
        return Button {
            selectedOption = option.label
        } label: {
            HStack(spacing: 12) {
                Text(option.label)
                    .font(.headline)
                    .foregroundStyle(isSelected ? Color.white : Color(red: 0.16, green: 0.33, blue: 0.24))
                    .frame(width: 36, height: 36)
                    .background(isSelected ? Color(red: 0.22, green: 0.76, blue: 0.39) : Color(red: 0.90, green: 0.97, blue: 0.92))
                    .clipShape(Circle())

                Text(option.content)
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.12, green: 0.2, blue: 0.16))

                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color(red: 0.90, green: 1.0, blue: 0.93) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color(red: 0.22, green: 0.76, blue: 0.39) : Color.clear, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func freeResponseField() -> some View {
        HStack(spacing: 12) {
            Image(systemName: "pencil.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color(red: 0.22, green: 0.76, blue: 0.39))

            TextField("Type your answer", text: $freeResponse)
                .textInputAutocapitalization(.never)
                .keyboardType(.numbersAndPunctuation)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 5)
        )
    }

    private func handleSwipe(_ value: DragGesture.Value) {
        if value.translation.height < -swipeThreshold {
            resetInputs()
            vm.advance()
        } else if value.translation.height > swipeThreshold {
            resetInputs()
            vm.retreat()
        }
    }

    private func resetInputs() {
        pendingAutoAdvance?.cancel()
        selectedOption = nil
        freeResponse = ""
        isInputFocused = false
    }

    private func loadAnswer(for question: Question) {
        pendingAutoAdvance?.cancel()
        if let options = question.options, !options.isEmpty {
            selectedOption = answers[question.id]
            freeResponse = ""
            isInputFocused = false
        } else {
            selectedOption = nil
            freeResponse = answers[question.id] ?? ""
        }
    }
}
