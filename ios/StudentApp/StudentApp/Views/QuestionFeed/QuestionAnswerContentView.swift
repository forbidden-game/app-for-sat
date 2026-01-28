import Combine
import SwiftUI
import UIKit
import StudentCore

struct QuestionAnswerContentView: View {
    let question: Question
    let answerPage: QuestionAnswerPage?
    let questionIndex: Int
    let total: Int
    @ObservedObject var state: QuestionFeedState
    @ObservedObject var store: InMemoryAnswerStore
    let submission: AnswerSubmissionCoordinator
    let questionStartedAt: Date
    @Binding var returnToOverviewOnAnswer: Bool
    let onShowOverview: () -> Void
    let onSubmissionError: (Error) -> Void

    @FocusState private var isInputFocused: Bool
    @State private var autoAdvanceTask: Task<Void, Never>?
    @State private var localFreeResponse: String = ""
    @State private var lastQuestionId: String = ""

    var body: some View {
        Group {
            if let answerPage {
                switch answerPage {
                case .options(let options):
                    optionsGrid(options, questionId: question.id, questionIndex: questionIndex)
                case .freeResponse:
                    freeResponseField(questionId: question.id, questionIndex: questionIndex)
                }
            } else if let options = question.options, !options.isEmpty {
                optionsGrid(options, questionId: question.id, questionIndex: questionIndex)
            } else {
                freeResponseField(questionId: question.id, questionIndex: questionIndex)
            }
        }
        .onAppear {
            syncLocalFreeResponse(force: true)
        }
        .onChange(of: question.id) { _, _ in
            syncLocalFreeResponse(force: true)
        }
        .onChange(of: state.inputState.freeResponse) { _, _ in
            if isCurrentQuestion {
                syncLocalFreeResponse(force: true)
            }
        }
        .onChange(of: isCurrentQuestion) { _, isActive in
            if !isActive {
                autoAdvanceTask?.cancel()
                autoAdvanceTask = nil
            }
            syncLocalFreeResponse(force: true)
        }
        .onDisappear {
            autoAdvanceTask?.cancel()
            autoAdvanceTask = nil
        }
        .onChange(of: state.inputState.isFocused) { _, newValue in
            guard isCurrentQuestion else { return }
            if isInputFocused != newValue {
                isInputFocused = newValue
            }
        }
        .onChange(of: isInputFocused) { _, newValue in
            guard isCurrentQuestion else { return }
            if state.inputState.isFocused != newValue {
                state.setFocus(newValue)
            }
        }
    }

    private var isCurrentQuestion: Bool {
        questionIndex == state.currentIndex
    }

    private func optionsGrid(_ options: [QuestionOption], questionId: String, questionIndex: Int) -> some View {
        VStack(spacing: 10) {
            ForEach(options, id: \.label) { option in
                optionButton(option, questionId: questionId, questionIndex: questionIndex)
            }
        }
    }

    private func optionButton(_ option: QuestionOption, questionId: String, questionIndex: Int) -> some View {
        let isCurrentQuestion = questionIndex == state.currentIndex
        let storedSelection = store[questionId]?.displayString
        let isSelected = isCurrentQuestion && storedSelection == option.label
        let isFeedback = isCurrentQuestion && state.inputState.showFeedback && isSelected
        let selectedFill = AppTheme.boardDark.opacity(0.22)
        let selectedStroke = AppTheme.boardDark
        let optionFill = isSelected ? selectedFill : AppTheme.surfaceRaised
        let optionStroke = isSelected ? selectedStroke : AppTheme.divider

        return Button {
            guard isCurrentQuestion else { return }
            triggerSelectionHaptic()
            withAnimation(.easeInOut(duration: AppMetrics.animationDurationFast)) {
                state.applySelection(.option(option.label))
            }
            recordAnswer(option.label, questionId: questionId)
            submitAnswer(questionId: questionId, answer: option.label)
            scheduleAutoAdvance(questionId: questionId)
        } label: {
            HStack(spacing: 12) {
                // ✅ Using OptionBadge component
                OptionBadge(label: option.label, isSelected: isSelected)

                MathTextView(text: option.content, style: .option)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding(.vertical, AppMetrics.rowPaddingVertical)
            .padding(.horizontal, AppMetrics.rowPaddingHorizontal)
            .appSurface(
                fill: optionFill,
                stroke: optionStroke,
                shadowRadius: AppMetrics.rowShadowRadius,
                shadowY: AppMetrics.rowShadowY,
                showShadow: isSelected
            )
            // ✅ Unified using AppMetrics.selectionIndicatorWidth
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(
                        cornerRadius: AppMetrics.selectionIndicatorCornerRadius,
                        style: .continuous
                    )
                    .fill(AppTheme.boardDark)
                    // ✅ Using AppMetrics.selectionIndicatorWidth
                    .frame(width: AppMetrics.selectionIndicatorWidth)
                    .padding(.vertical, 8)
                    .offset(x: 6)
                }
            }
            .scaleEffect(isFeedback ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("question_option_\(questionId)_\(option.label)")
        .disabled(!isCurrentQuestion)
    }

    private func freeResponseField(questionId: String, questionIndex: Int) -> some View {
        let isCurrentQuestion = questionIndex == state.currentIndex
        let showingFeedback = isCurrentQuestion && state.inputState.showFeedback
        let isEnabled = isCurrentQuestion
        let storedValue = store[questionId]?.displayString ?? ""

        return HStack(spacing: 12) {
            Image(systemName: "pencil.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(showingFeedback ? AppTheme.accentStrong : AppTheme.accent)

            TextField("Type your answer", text: isCurrentQuestion ? freeResponseBinding : .constant(storedValue))
                .focused($isInputFocused)
                .textInputAutocapitalization(.never)
                .keyboardType(.numbersAndPunctuation)
                .submitLabel(.done)
                .onSubmit {
                    if isCurrentQuestion {
                        commitFreeResponse(questionId: questionId)
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Button("Done") {
                            state.setFocus(false)
                        }
                        Spacer()
                        Button("Next") {
                            if isCurrentQuestion {
                                commitFreeResponse(questionId: questionId)
                            } else {
                                state.setFocus(false)
                            }
                        }
                        .disabled(!isCurrentQuestion)
                    }
                }
                .foregroundStyle(isEnabled ? AppTheme.textPrimary : AppTheme.textMuted)
                .disabled(!isCurrentQuestion)
                .accessibilityIdentifier("question_free_response_\(questionId)")
        }
        .padding(.vertical, AppMetrics.fieldPaddingVertical)
        .padding(.horizontal, AppMetrics.fieldPaddingHorizontal)
        .appSurface(
            fill: showingFeedback ? AppTheme.surfacePressed : AppTheme.surfaceRaised,
            stroke: showingFeedback ? AppTheme.accentStrong : (isEnabled ? AppTheme.dividerStrong : AppTheme.divider),
            shadowRadius: AppMetrics.rowShadowRadius,
            shadowY: AppMetrics.rowShadowY
        )
        .scaleEffect(showingFeedback ? 0.98 : 1.0)
    }

    private var freeResponseBinding: Binding<String> {
        Binding(
            get: { isCurrentQuestion ? localFreeResponse : (store[question.id]?.displayString ?? "") },
            set: { newValue in
                guard isCurrentQuestion else { return }
                localFreeResponse = newValue
                state.updateFreeResponse(newValue, questionId: question.id)
            }
        )
    }

    private func commitFreeResponse(questionId: String) {
        let trimmed = localFreeResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        state.setFocus(false)
        triggerSelectionHaptic()
        recordAnswer(trimmed, questionId: questionId)
        withAnimation(.easeInOut(duration: 0.15)) {
            state.applySelection(.freeResponse(trimmed))
        }
        submitAnswer(questionId: questionId, answer: trimmed)
        scheduleAutoAdvance(questionId: questionId)
    }

    private func recordAnswer(_ value: String, questionId: String) {
        store[questionId] = .string(value)
        state.clearDraft(for: questionId)
    }

    private func submitAnswer(questionId: String, answer: String) {
        let durationMs = AttemptDuration.milliseconds(from: questionStartedAt)
        submission.submit(
            question: question,
            answer: answer,
            durationMs: durationMs,
            questionId: questionId,
            onSuccess: { _ in },
            onFailure: { error in
                submissionError(error)
            }
        )
    }

    private func submissionError(_ error: Error) {
        state.setFeedbackVisible(false)
        onSubmissionError(error)
    }

    private func advanceAfterAnswer() {
        resetInputs()
        let isLast = questionIndex == total - 1
        if returnToOverviewOnAnswer || isLast {
            returnToOverviewOnAnswer = false
            onShowOverview()
        } else {
            state.advance(total: total)
        }
    }

    private func resetInputs() {
        state.setFocus(false)
        state.setFeedbackVisible(false)
        state.clearAutoAdvance()
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
    }

    private func scheduleAutoAdvance(questionId: String) {
        autoAdvanceTask?.cancel()
        state.scheduleAutoAdvance(for: questionId)
        autoAdvanceTask = Task {
            let delayMs = max(AppConfig.autoAdvanceDelayMs, 80)
            try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
            await MainActor.run {
                guard state.autoAdvanceState.scheduledForQuestionId == questionId else { return }
                guard isCurrentQuestion else { return }
                state.setFeedbackVisible(false)
                advanceAfterAnswer()
            }
        }
    }

    private func syncLocalFreeResponse(force: Bool) {
        let storedValue = store[question.id]?.displayString ?? ""
        if lastQuestionId != question.id || force {
            if isCurrentQuestion {
                localFreeResponse = state.inputState.freeResponse
            } else {
                localFreeResponse = storedValue
            }
            lastQuestionId = question.id
            return
        }
        if isCurrentQuestion {
            localFreeResponse = state.inputState.freeResponse
        } else {
            localFreeResponse = storedValue
        }
    }
}

func triggerSelectionHaptic() {
    #if canImport(UIKit)
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.impactOccurred()
    #endif
}
