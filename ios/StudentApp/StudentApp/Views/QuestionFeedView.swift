import SwiftUI
import StudentCore
#if canImport(UIKit)
import UIKit
#endif

struct QuestionFeedView: View {
    @StateObject var vm: QuestionFeedViewModel
    @Binding var answers: [String: String]
    @Binding var returnToOverviewOnAnswer: Bool
    let onShowOverview: () -> Void
    let onAnswer: (Question, String) -> Void

    @State private var selectedOption: String?
    @State private var freeResponse: String = ""
    @State private var pendingAutoAdvance: DispatchWorkItem?
    @FocusState private var isInputFocused: Bool
    @State private var dragOffset: CGFloat = 0

    private let commitThreshold: CGFloat = 120
    private let rubberBandFactor: CGFloat = 0.25

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

            ZStack {
                if dragOffset < 0, let nextQuestion = nextQuestion {
                    previewCard(question: nextQuestion, direction: .next, progress: previewProgress)
                }
                if dragOffset > 0, let previousQuestion = previousQuestion {
                    previewCard(question: previousQuestion, direction: .previous, progress: previewProgress)
                }

                currentContent(question: question, total: total, progress: progress)
                    .offset(y: dragOffset)
                    .scaleEffect(1 - previewProgress * 0.03)
            }
        }
        .contentShape(Rectangle())
        .highPriorityGesture(dragGesture)
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

    private func currentContent(question: Question, total: Int, progress: Double) -> some View {
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

    private func previewCard(question: Question, direction: SwipeDirection, progress: CGFloat) -> some View {
        let baseOffset: CGFloat = direction == .next ? 140 : -140
        let offset = baseOffset * (1 - progress)
        let scale = 0.94 + 0.06 * progress
        let opacity = 0.15 + 0.85 * progress

        return VStack(spacing: 16) {
            Text(direction == .next ? "Next Question" : "Previous Question")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            questionCard(text: question.stem)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .scaleEffect(scale)
        .opacity(opacity)
        .offset(y: offset)
        .allowsHitTesting(false)
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
        onAnswer(question, value)
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

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                if abs(value.translation.height) > 4 {
                    isInputFocused = false
                }
                let translation = value.translation.height
                let isMovingDown = translation > 0
                let isMovingUp = translation < 0
                var adjusted = translation
                if (isMovingDown && !canRetreat) || (isMovingUp && !canAdvance) {
                    adjusted = translation * rubberBandFactor
                }
                dragOffset = adjusted
            }
            .onEnded { value in
                let translation = value.translation.height
                let shouldAdvance = translation < -commitThreshold && canAdvance
                let shouldRetreat = translation > commitThreshold && canRetreat
                if shouldAdvance || shouldRetreat {
                    triggerHaptic()
                }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    if shouldAdvance {
                        resetInputs()
                        vm.advance()
                    } else if shouldRetreat {
                        resetInputs()
                        vm.retreat()
                    }
                    dragOffset = 0
                }
            }
    }

    private var canAdvance: Bool {
        vm.currentIndex + 1 < vm.session.questions.count
    }

    private var canRetreat: Bool {
        vm.currentIndex > 0
    }

    private var previewProgress: CGFloat {
        min(abs(dragOffset) / commitThreshold, 1)
    }

    private var nextQuestion: Question? {
        let nextIndex = vm.currentIndex + 1
        guard nextIndex < vm.session.questions.count else { return nil }
        return vm.session.questions[nextIndex]
    }

    private var previousQuestion: Question? {
        let previousIndex = vm.currentIndex - 1
        guard previousIndex >= 0 else { return nil }
        return vm.session.questions[previousIndex]
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

private enum SwipeDirection {
    case previous
    case next
}

private func triggerHaptic() {
    #if canImport(UIKit)
    let generator = UIImpactFeedbackGenerator(style: .light)
    generator.impactOccurred()
    #endif
}
