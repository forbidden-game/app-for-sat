import SwiftUI
import StudentCore
#if canImport(UIKit)
import UIKit
#endif

struct QuestionFeedView: View {
    let session: PracticeSession
    @ObservedObject var state: QuestionFeedState
    @ObservedObject var store: InMemoryAnswerStore
    let submission: AnswerSubmissionCoordinator
    @Binding var returnToOverviewOnAnswer: Bool
    let headerTitle: String?
    let onBack: () -> Void
    let onShowOverview: () -> Void
    let onSubmissionError: (Error) -> Void

    @FocusState private var isInputFocused: Bool
    @State private var autoAdvanceTask: Task<Void, Never>?
    @State private var perfTask: Task<Void, Never>?
    @State private var perfDirection = 1
    @State private var canPageUp = true
    @State private var canPageDown = true

    var body: some View {
        let total = session.questions.count

        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            VerticalPagingView(
                pageCount: total + 1,
                currentPage: currentPageBinding,
                canPageUp: $canPageUp,
                canPageDown: $canPageDown
            ) { index in
                if index < total {
                    questionPage(question: session.questions[index], index: index, total: total)
                } else {
                    overviewTriggerCard(total: total)
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            if session.questions.indices.contains(state.currentIndex) {
                loadAnswer(for: session.questions[state.currentIndex])
            }
            startPerfAutoPaging(total: total)
        }
        .onDisappear {
            stopPerfAutoPaging()
            submission.cancelAll()
        }
        .onChange(of: state.currentIndex) { _, newIndex in
            if newIndex >= 0, newIndex < session.questions.count {
                canPageUp = true
                canPageDown = true
                state.setFocus(false)
                loadAnswer(for: session.questions[newIndex])
            }
        }
        .onChange(of: state.inputState.isFocused) { _, newValue in
            if isInputFocused != newValue {
                isInputFocused = newValue
            }
        }
        .onChange(of: isInputFocused) { _, newValue in
            if state.inputState.isFocused != newValue {
                state.setFocus(newValue)
            }
        }
    }

    // MARK: - Question Page

    private func questionPage(question: Question, index: Int, total: Int) -> some View {
        let progress = total > 0 ? Double(index + 1) / Double(total) : 0
        
        return ZStack(alignment: .top) {
            Color.clear

            GeometryReader { proxy in
                VStack(spacing: AppMetrics.sectionSpacing) {
                    header(progress: progress, index: index + 1, total: total, question: question)

                    ScrollBoundaryScrollView(
                        isActive: index == state.currentIndex,
                        isScrollEnabled: index == state.currentIndex,
                        scrollResetID: question.id,
                        canPageUp: $canPageUp,
                        canPageDown: $canPageDown
                    ) {
                        VStack(spacing: AppMetrics.sectionSpacing) {
                            questionCard(text: question.stem)

                            if let options = question.options, !options.isEmpty {
                                optionsGrid(options, questionId: question.id, questionIndex: index)
                            } else {
                                freeResponseField(questionId: question.id, questionIndex: index)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, AppMetrics.pageBottomPadding)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .clipped()
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Overview Trigger Card

    private func overviewTriggerCard(total: Int) -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(AppTheme.accent)
            
            Text("Review Your Answers")
                .font(.title2.bold())
                .foregroundStyle(AppTheme.textPrimary)

            Text("Swipe up to see overview")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textMuted)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }


    // MARK: - Header

    private func header(progress: Double, index: Int, total: Int, question: Question) -> some View {
        VStack(spacing: AppMetrics.headerSpacing) {
            ZStack {
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(AppTheme.surface)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(AppTheme.divider, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("\(index)/\(total)")
                        .font(.subheadline)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .foregroundStyle(AppTheme.textPrimary)
                        .background(AppTheme.surfaceRaised)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(AppTheme.divider, lineWidth: 1)
                        )
                }

                Text(resolvedHeaderTitle(for: question))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            ProgressView(value: progress)
                .tint(AppTheme.accent)

            answerStatusPill(for: question)
        }
    }

    // MARK: - Question Card

    private func questionCard(text: String) -> some View {
        MathTextView(text: text, style: .questionStem)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppMetrics.cardPadding)
            .appSurface(
                fill: AppTheme.surface,
                stroke: AppTheme.divider,
                cornerRadius: AppMetrics.cardCornerRadius,
                shadowRadius: AppMetrics.cardShadowRadius,
                shadowY: AppMetrics.cardShadowY
            )
    }

    // MARK: - Options Grid

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
        let badgeFill = isSelected ? AppTheme.accentStrong : AppTheme.surfaceRaised
        let badgeStroke = isSelected ? AppTheme.accentStrong : AppTheme.dividerStrong
        let badgeText = isSelected ? AppTheme.textOnAccent : AppTheme.textSecondary
        let optionFill = isSelected ? AppTheme.accentSoft : AppTheme.surface
        let optionStroke = isSelected ? AppTheme.accentStrong : AppTheme.divider

        return Button {
            guard isCurrentQuestion else { return }
            triggerSelectionHaptic()
            withAnimation(.easeInOut(duration: 0.15)) {
                state.applySelection(.option(option.label))
            }
            recordAnswer(option.label, questionId: questionId)
            submitAnswer(questionId: questionId, answer: option.label)
            scheduleAutoAdvance(questionId: questionId)
        } label: {
            HStack(spacing: 12) {
                Text(option.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(badgeText)
                    .frame(width: AppMetrics.badgeSize, height: AppMetrics.badgeSize)
                    .background(badgeFill)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(badgeStroke, lineWidth: isSelected ? 2 : 1)
                    )

                MathTextView(text: option.content, style: .option)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding(.vertical, AppMetrics.rowPaddingVertical)
            .padding(.horizontal, AppMetrics.rowPaddingHorizontal)
            .appSurface(
                fill: isSelected ? optionFill : AppTheme.surfaceRaised,
                stroke: optionStroke,
                shadowRadius: AppMetrics.rowShadowRadius,
                shadowY: AppMetrics.rowShadowY,
                showShadow: isSelected
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(AppTheme.accentStrong)
                        .frame(width: 4)
                        .padding(.vertical, 8)
                        .offset(x: 6)
                }
            }
            .scaleEffect(isFeedback ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(!isCurrentQuestion)
    }

    // MARK: - Free Response

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
                .foregroundStyle(isEnabled ? AppTheme.textPrimary : AppTheme.textMuted)
                .disabled(!isCurrentQuestion)
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

    // MARK: - Helper Methods

    private func questionTitle(for question: Question) -> String {
        let raw = question.questionType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "Question" }
        let cleaned = raw
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        let parts = cleaned.split { !$0.isLetter && !$0.isNumber }
        let title = parts.map { $0.capitalized }.joined(separator: " ")
        return title.isEmpty ? "Question" : title
    }

    private func resolvedHeaderTitle(for question: Question) -> String {
        if let headerTitle, !headerTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return headerTitle
        }
        return questionTitle(for: question)
    }

    private func answerStatusPill(for question: Question) -> some View {
        let raw = store[question.id]?.displayString ?? ""
        let isAnswered = !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let title = isAnswered ? "Answered · Editable" : "Not answered"
        let icon = isAnswered ? "checkmark.seal.fill" : "circle"
        let fill = isAnswered ? AppTheme.accentSoft : AppTheme.surfaceRaised
        let stroke = isAnswered ? AppTheme.accentStrong : AppTheme.divider
        let textColor = isAnswered ? AppTheme.accentStrong : AppTheme.textMuted

        return HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(textColor)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(fill)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(stroke, lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var freeResponseBinding: Binding<String> {
        Binding(
            get: { state.inputState.freeResponse },
            set: { state.updateFreeResponse($0) }
        )
    }

    private func commitFreeResponse(questionId: String) {
        let trimmed = state.inputState.freeResponse.trimmingCharacters(in: .whitespacesAndNewlines)
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
    }

    private func submitAnswer(questionId: String, answer: String) {
        guard let question = session.questions.first(where: { $0.id == questionId }) else { return }
        submission.submit(
            question: question,
            answer: answer,
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
        let isLast = state.currentIndex == session.questions.count - 1
        if returnToOverviewOnAnswer || isLast {
            returnToOverviewOnAnswer = false
            onShowOverview()
        } else {
            state.advance(total: session.questions.count)
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
                guard currentQuestionId() == questionId else { return }
                state.setFeedbackVisible(false)
                advanceAfterAnswer()
            }
        }
    }

    private func loadAnswer(for question: Question) {
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
        let isMultipleChoice = (question.options?.isEmpty == false)
        state.resetInput(for: question.id, from: store, isMultipleChoice: isMultipleChoice)
    }

    private func currentQuestionId() -> String? {
        guard state.currentIndex >= 0, state.currentIndex < session.questions.count else { return nil }
        return session.questions[state.currentIndex].id
    }

    // MARK: - Perf Harness

    private func startPerfAutoPaging(total: Int) {
        let config = PerfHarnessConfig.current
        guard config.isEnabled, perfTask == nil else { return }
        guard total > 1 else { return }

        perfTask = Task {
            let endTime = Date().addingTimeInterval(config.durationSeconds)
            while Date() < endTime, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(config.paceSeconds * 1_000_000_000))
                await MainActor.run {
                    guard total > 1 else { return }
                    state.setFocus(false)
                    let lastIndex = total - 1
                    if perfDirection > 0 {
                        if state.currentIndex >= lastIndex {
                            perfDirection = -1
                            state.jump(to: max(lastIndex - 1, 0), total: total)
                        } else {
                            state.advance(total: total)
                        }
                    } else {
                        if state.currentIndex <= 0 {
                            perfDirection = 1
                            state.jump(to: min(1, lastIndex), total: total)
                        } else {
                            state.retreat()
                        }
                    }
                }
            }
        }
    }

    private func stopPerfAutoPaging() {
        perfTask?.cancel()
        perfTask = nil
    }

    private var currentPageBinding: Binding<Int> {
        Binding(
            get: { state.currentIndex },
            set: { newPage in
                let total = session.questions.count
                guard total > 0 else { return }
                if newPage >= total {
                    triggerHaptic()
                    onShowOverview()
                    return
                }
                guard newPage >= 0, newPage != state.currentIndex else { return }
                triggerHaptic()
                state.setFocus(false)
                state.jump(to: newPage, total: total)
            }
        )
    }
}

// MARK: - Haptics

private func triggerHaptic() {
    #if canImport(UIKit)
    let generator = UIImpactFeedbackGenerator(style: .light)
    generator.impactOccurred()
    #endif
}

private func triggerSelectionHaptic() {
    #if canImport(UIKit)
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.impactOccurred()
    #endif
}
