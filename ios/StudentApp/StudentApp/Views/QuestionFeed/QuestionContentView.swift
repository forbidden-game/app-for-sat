import SwiftUI
import UIKit
import StudentCore

struct QuestionContentView: View {
    let question: Question
    let index: Int
    let total: Int
    @ObservedObject var state: QuestionFeedState
    @ObservedObject var store: InMemoryAnswerStore
    let submission: AnswerSubmissionCoordinator
    @Binding var returnToOverviewOnAnswer: Bool
    let headerTitle: String?
    let onBack: () -> Void
    let onShowOverview: () -> Void
    let onSubmissionError: (Error) -> Void
    let outerPan: UIPanGestureRecognizer?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    @FocusState private var isInputFocused: Bool
    @State private var autoAdvanceTask: Task<Void, Never>?
    @State private var localFreeResponse: String = ""
    @State private var lastQuestionId: String = ""
    @State private var layout: QuestionBodyLayout = .short
    @State private var layoutReady = false
    @State private var layoutTask: Task<Void, Never>?
    @State private var layoutSignature: LayoutSignature?
    @State private var lastLayoutSize: CGSize = .zero

    var body: some View {
        let progress = total > 0 ? Double(index + 1) / Double(total) : 0

        VStack(spacing: AppMetrics.sectionSpacing) {
            header(progress: progress, index: index + 1, total: total, question: question)

            GeometryReader { proxy in
                let size = proxy.size
                ZStack(alignment: .top) {
                    if layoutReady {
                        bodyLayout()
                    } else {
                        ProgressView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .onAppear {
                    updateLayoutIfNeeded(size: size)
                }
                .onChange(of: size) { _, newSize in
                    updateLayoutIfNeeded(size: newSize)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, AppMetrics.pageBottomPadding)
        .onAppear {
            syncLocalFreeResponse(force: true)
        }
        .onChange(of: question.id) { _, _ in
            resetLayout()
            syncLocalFreeResponse(force: true)
        }
        .onChange(of: colorScheme) { _, _ in
            resetLayout()
        }
        .onChange(of: displayScale) { _, _ in
            resetLayout()
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
            layoutTask?.cancel()
            layoutTask = nil
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
        index == state.currentIndex
    }

    private func bodyLayout() -> some View {
        switch layout {
        case .short:
            return AnyView(shortBodyLayout())
        case .long(let stemPages):
            return AnyView(longBodyLayout(stemPages: stemPages))
        }
    }

    private func shortBodyLayout() -> some View {
        VStack(spacing: AppMetrics.sectionSpacing) {
            questionCard(text: question.stem)
            answerContent(questionId: question.id, questionIndex: index)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func longBodyLayout(stemPages: [String]) -> some View {
        let pages = stemPages.map { QuestionHorizontalPage.stem($0) } + [.answer]
        let pageCount = pages.count
        let currentIndex = clampPageIndex(state.stemPage(for: question.id), pageCount: pageCount)

        return ZStack(alignment: .bottomTrailing) {
            QuestionHorizontalPagerView(
                pages: pages,
                currentIndex: currentIndex,
                outerPan: outerPan,
                onPageChange: { newIndex in
                    state.setStemPage(newIndex, for: question.id)
                },
                onUserInteraction: {
                    state.markSeenStemSwipeHint(for: question.id)
                },
                pageBuilder: { page in
                    switch page {
                    case .stem(let text):
                        return AnyView(stemPageView(text: text))
                    case .answer:
                        return AnyView(answerPageView(questionId: question.id, questionIndex: index))
                    }
                }
            )

            if pageCount > 1 {
                pageIndicator(current: currentIndex + 1, total: pageCount)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if shouldShowSwipeHint(pageCount: pageCount) {
                swipeHint
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: state.hasSeenStemSwipeHint(for: question.id))
    }

    private func stemPageView(text: String) -> some View {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
    }

    private func answerPageView(questionId: String, questionIndex: Int) -> some View {
        VStack(spacing: AppMetrics.sectionSpacing) {
            answerContent(questionId: questionId, questionIndex: questionIndex)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func answerContent(questionId: String, questionIndex: Int) -> some View {
        Group {
            if let options = question.options, !options.isEmpty {
                optionsGrid(options, questionId: questionId, questionIndex: questionIndex)
            } else {
                freeResponseField(questionId: questionId, questionIndex: questionIndex)
            }
        }
    }

    private func shouldShowSwipeHint(pageCount: Int) -> Bool {
        pageCount > 1 && !state.hasSeenStemSwipeHint(for: question.id)
    }

    private func pageIndicator(current: Int, total: Int) -> some View {
        Text("\(current)/\(total)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.textOnAccent)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(AppTheme.accentStrong.opacity(0.9))
            .clipShape(Capsule())
            .padding(8)
    }

    private var swipeHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.left.and.right")
                .font(.caption.weight(.semibold))
            Text("Swipe left/right")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(AppTheme.textMuted)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(AppTheme.surface.opacity(0.9))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(AppTheme.divider, lineWidth: 1)
        )
        .padding(8)
    }

    private func clampPageIndex(_ index: Int, pageCount: Int) -> Int {
        guard pageCount > 0 else { return 0 }
        return max(0, min(index, pageCount - 1))
    }

    private func resetLayout() {
        layoutTask?.cancel()
        layoutTask = nil
        layoutReady = false
        layoutSignature = nil
        if lastLayoutSize != .zero {
            updateLayoutIfNeeded(size: lastLayoutSize)
        }
    }

    private func updateLayoutIfNeeded(size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let signature = LayoutSignature(
            questionId: question.id,
            widthBucket: Int(size.width.rounded(.up)),
            heightBucket: Int(size.height.rounded(.up)),
            scheme: colorScheme == .dark ? "dark" : "light",
            scaleBucket: String(format: "%.2f", displayScale)
        )
        guard signature != layoutSignature else { return }
        layoutSignature = signature
        lastLayoutSize = size
        layoutReady = false

        layoutTask?.cancel()
        layoutTask = Task {
            let result = await QuestionLayoutEngine.shared.layout(
                question: question,
                size: size,
                colorScheme: colorScheme,
                displayScale: displayScale,
                textColor: AppTheme.textPrimary
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                layout = result
                layoutReady = true
                if case .long(let pages) = result {
                    let pageCount = pages.count + 1
                    let clamped = clampPageIndex(state.stemPage(for: question.id), pageCount: pageCount)
                    if clamped != state.stemPage(for: question.id) {
                        state.setStemPage(clamped, for: question.id)
                    }
                } else {
                    state.setStemPage(0, for: question.id)
                }
            }
        }
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
                    .fixedSize(horizontal: false, vertical: true)

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
            get: { isCurrentQuestion ? localFreeResponse : (store[question.id]?.displayString ?? "") },
            set: { newValue in
                guard isCurrentQuestion else { return }
                localFreeResponse = newValue
                state.updateFreeResponse(newValue)
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
    }

    private func submitAnswer(questionId: String, answer: String) {
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
        let isLast = index == total - 1
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

private struct LayoutSignature: Equatable {
    let questionId: String
    let widthBucket: Int
    let heightBucket: Int
    let scheme: String
    let scaleBucket: String
}

struct QuestionOverviewView: View {
    let total: Int

    var body: some View {
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
}

private func triggerSelectionHaptic() {
    #if canImport(UIKit)
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.impactOccurred()
    #endif
}
