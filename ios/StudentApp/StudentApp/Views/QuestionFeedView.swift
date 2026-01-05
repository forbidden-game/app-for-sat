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
    @State private var isTransitioning = false
    @State private var transitionFromIndex: Int?
    @State private var transitionToIndex: Int?
    @State private var transitionDirection: SwipeDirection?
    @State private var transitionOffset: CGFloat = 0

    private let commitThreshold: CGFloat = 120
    private let rubberBandFactor: CGFloat = 0.25
    private let transitionDuration: UInt64 = 380_000_000

    var body: some View {
        let question = vm.session.questions[vm.currentIndex]
        let total = vm.session.questions.count

        ZStack {
            LinearGradient(
                colors: [Color(red: 0.87, green: 0.98, blue: 0.93), Color(red: 0.90, green: 0.95, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GeometryReader { proxy in
                let height = proxy.size.height
                ZStack {
                    if isTransitioning,
                       let fromIndex = transitionFromIndex,
                       let toIndex = transitionToIndex,
                       let direction = transitionDirection {
                        let fromQuestion = vm.session.questions[fromIndex]
                        let toQuestion = vm.session.questions[toIndex]
                        currentContent(question: fromQuestion, total: total, index: fromIndex)
                            .offset(y: transitionOffset)
                        currentContent(question: toQuestion, total: total, index: toIndex)
                            .offset(y: transitionOffset + (direction == .next ? height : -height))
                    } else {
                        if let target = dragTarget(height: height) {
                            currentContent(question: target.question, total: total, index: target.index)
                                .offset(y: target.offset)
                        }

                        currentContent(question: question, total: total, index: vm.currentIndex)
                            .offset(y: dragOffset)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .contentShape(Rectangle())
                .highPriorityGesture(dragGesture(height: height))
                .allowsHitTesting(!isTransitioning)
            }
        }
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

    private func currentContent(question: Question, total: Int, index: Int) -> some View {
        let progress = total > 0 ? Double(index + 1) / Double(total) : 0
        return VStack(spacing: 20) {
            header(progress: progress, index: index + 1, total: total)

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

    private func dragGesture(height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isTransitioning else { return }
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
                guard !isTransitioning else { return }
                let translation = value.translation.height
                let shouldAdvance = translation < -commitThreshold && canAdvance
                let shouldRetreat = translation > commitThreshold && canRetreat
                if shouldAdvance {
                    triggerHaptic()
                    resetInputs()
                    beginTransition(direction: .next, height: height, startingOffset: dragOffset)
                } else if shouldRetreat {
                    triggerHaptic()
                    resetInputs()
                    beginTransition(direction: .previous, height: height, startingOffset: dragOffset)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        dragOffset = 0
                    }
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

    private struct DragTarget {
        let question: Question
        let index: Int
        let offset: CGFloat
    }

    private func dragTarget(height: CGFloat) -> DragTarget? {
        guard dragOffset != 0 else { return nil }
        if dragOffset < 0, let nextQuestion = nextQuestion {
            return DragTarget(
                question: nextQuestion,
                index: vm.currentIndex + 1,
                offset: dragOffset + height
            )
        }
        if dragOffset > 0, let previousQuestion = previousQuestion {
            return DragTarget(
                question: previousQuestion,
                index: vm.currentIndex - 1,
                offset: dragOffset - height
            )
        }
        return nil
    }

    private func beginTransition(direction: SwipeDirection, height: CGFloat, startingOffset: CGFloat) {
        let fromIndex = vm.currentIndex
        let toIndex = direction == .next ? fromIndex + 1 : fromIndex - 1
        guard toIndex >= 0 && toIndex < vm.session.questions.count else { return }

        isTransitioning = true
        transitionFromIndex = fromIndex
        transitionToIndex = toIndex
        transitionDirection = direction
        transitionOffset = startingOffset

        let target = direction == .next ? -height : height
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            transitionOffset = target
        }

        Task {
            try? await Task.sleep(nanoseconds: transitionDuration)
            vm.jump(to: toIndex)
            dragOffset = 0
            transitionOffset = 0
            transitionFromIndex = nil
            transitionToIndex = nil
            transitionDirection = nil
            isTransitioning = false
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
