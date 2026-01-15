import SwiftUI
import StudentCore
#if canImport(UIKit)
import UIKit
#endif

struct QuestionFeedView: View {
    let studentId: String
    @StateObject var vm: QuestionFeedViewModel
    @Binding var answers: [String: String]
    @Binding var returnToOverviewOnAnswer: Bool
    let headerTitle: String?
    @ObservedObject var flowModel: PracticeFlowViewModel
    let onBack: () -> Void
    let onShowOverview: () -> Void

    @State private var selectedOption: String?
    @State private var freeResponse: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var showFeedback = false
    @State private var currentPage = 0
    @State private var autoAdvanceTask: Task<Void, Never>?
    @State private var perfTask: Task<Void, Never>?
    @State private var perfDirection = 1
    @State private var canPageUp = true
    @State private var canPageDown = true

    var body: some View {
        let total = vm.session.questions.count

        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            VerticalPagingView(
                pageCount: total + 1,
                currentPage: $currentPage,
                canPageUp: $canPageUp,
                canPageDown: $canPageDown
            ) { index in
                if index < total {
                    questionPage(question: vm.session.questions[index], index: index, total: total)
                } else {
                    overviewTriggerCard(total: total)
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            currentPage = vm.currentIndex
            loadAnswer(for: vm.session.questions[vm.currentIndex])
            startPerfAutoPaging(total: total)
        }
        .onDisappear {
            stopPerfAutoPaging()
        }
        .onChange(of: currentPage) { _, newPage in
            if newPage >= vm.session.questions.count {
                triggerHaptic()
                onShowOverview()
                currentPage = vm.session.questions.count - 1
                return
            }
            
            if newPage != vm.currentIndex {
                triggerHaptic()
                isInputFocused = false
                vm.jump(to: newPage)
                loadAnswer(for: vm.session.questions[newPage])
            }
        }
        .onChange(of: vm.currentIndex) { _, newIndex in
            if currentPage != newIndex {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    currentPage = newIndex
                }
            }
        }
    }

    // MARK: - Question Page

    private func questionPage(question: Question, index: Int, total: Int) -> some View {
        let progress = total > 0 ? Double(index + 1) / Double(total) : 0
        
        return ZStack(alignment: .top) {
            Color.clear

            VStack(spacing: AppMetrics.sectionSpacing) {
                header(progress: progress, index: index + 1, total: total, question: question)

                ScrollBoundaryScrollView(
                    isActive: index == currentPage,
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
        let isCurrentQuestion = questionIndex == vm.currentIndex
        let isSelected = isCurrentQuestion && selectedOption == option.label
        let isFeedback = isCurrentQuestion && showFeedback && isSelected
        let badgeFill = isSelected ? AppTheme.accentStrong : AppTheme.surfaceRaised
        let badgeStroke = isSelected ? AppTheme.accentStrong : AppTheme.dividerStrong
        let badgeText = isSelected ? AppTheme.textOnAccent : AppTheme.textSecondary
        let optionFill = isSelected ? AppTheme.accentSoft : AppTheme.surface
        let optionStroke = isSelected ? AppTheme.accentStrong : AppTheme.divider

        return Button {
            guard isCurrentQuestion, !showFeedback else { return }
            selectedOption = option.label
            triggerSelectionHaptic()
            withAnimation(.easeInOut(duration: 0.15)) {
                showFeedback = true
            }
            recordAnswer(option.label, questionId: questionId)
            submitAnswer(questionIndex: questionIndex, answer: option.label)
            scheduleAutoAdvance(questionIndex: questionIndex)
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
        .disabled(!isCurrentQuestion || showFeedback)
    }

    // MARK: - Free Response

    private func freeResponseField(questionId: String, questionIndex: Int) -> some View {
        let isCurrentQuestion = questionIndex == vm.currentIndex
        let showingFeedback = isCurrentQuestion && showFeedback
        let isEnabled = isCurrentQuestion && !showFeedback
        
        return HStack(spacing: 12) {
            Image(systemName: "pencil.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(showingFeedback ? AppTheme.accentStrong : AppTheme.accent)

            TextField("Type your answer", text: isCurrentQuestion ? $freeResponse : .constant(answers[questionId] ?? ""))
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
                .disabled(!isCurrentQuestion || showFeedback)
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

    private func commitFreeResponse(questionId: String) {
        let trimmed = freeResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !showFeedback else { return }
        isInputFocused = false
        triggerSelectionHaptic()
        recordAnswer(trimmed, questionId: questionId)
        withAnimation(.easeInOut(duration: 0.15)) {
            showFeedback = true
        }
        submitAnswer(questionIndex: vm.currentIndex, answer: trimmed)
        scheduleAutoAdvance(questionIndex: vm.currentIndex)
    }

    private func recordAnswer(_ value: String, questionId: String) {
        answers[questionId] = value
    }

    private func submitAnswer(questionIndex: Int, answer: String) {
        guard questionIndex >= 0, questionIndex < vm.session.questions.count else { return }
        let question = vm.session.questions[questionIndex]

        Task {
            do {
                _ = try await flowModel.submitAnswer(question: question, answer: answer, allowCoach: false)
            } catch {
                submissionError(error)
            }
        }
    }

    private func submissionError(_ error: Error) {
        showFeedback = false
        flowModel.submissionError = error.localizedDescription
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

    private func resetInputs() {
        selectedOption = nil
        freeResponse = ""
        isInputFocused = false
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
    }

    private func scheduleAutoAdvance(questionIndex: Int) {
        autoAdvanceTask?.cancel()
        autoAdvanceTask = Task {
            let delayMs = max(AppConfig.autoAdvanceDelayMs, 80)
            try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
            await MainActor.run {
                guard vm.currentIndex == questionIndex, showFeedback else { return }
                showFeedback = false
                advanceAfterAnswer()
            }
        }
    }

    private func loadAnswer(for question: Question) {
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
        if let options = question.options, !options.isEmpty {
            selectedOption = answers[question.id]
            freeResponse = ""
            isInputFocused = false
        } else {
            selectedOption = nil
            freeResponse = answers[question.id] ?? ""
        }
        showFeedback = false
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
                    isInputFocused = false
                    let lastIndex = total - 1
                    if perfDirection > 0 {
                        if currentPage >= lastIndex {
                            perfDirection = -1
                            currentPage = max(lastIndex - 1, 0)
                        } else {
                            currentPage += 1
                        }
                    } else {
                        if currentPage <= 0 {
                            perfDirection = 1
                            currentPage = min(1, lastIndex)
                        } else {
                            currentPage -= 1
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

// MARK: - Scroll Boundary Helpers

private struct ScrollBoundaryScrollView<Content: View>: View {
    let isActive: Bool
    @Binding var canPageUp: Bool
    @Binding var canPageDown: Bool
    let content: Content

    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var offsetY: CGFloat = 0

    init(isActive: Bool, canPageUp: Binding<Bool>, canPageDown: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.isActive = isActive
        self._canPageUp = canPageUp
        self._canPageDown = canPageDown
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: 0)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: ScrollOffsetKey.self,
                                value: proxy.frame(in: .named("scroll")).minY
                            )
                        }
                    )

                content
            }
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: ContentHeightKey.self, value: proxy.size.height)
                }
            )
        }
        .coordinateSpace(name: "scroll")
        .scrollIndicators(.hidden)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: ViewportHeightKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(ScrollOffsetKey.self) { offset in
            offsetY = offset
            updatePagingState()
        }
        .onPreferenceChange(ContentHeightKey.self) { height in
            contentHeight = height
            updatePagingState()
        }
        .onPreferenceChange(ViewportHeightKey.self) { height in
            viewportHeight = height
            updatePagingState()
        }
    }

    private func updatePagingState() {
        guard isActive else { return }
        let maxScroll = max(contentHeight - viewportHeight, 0)
        let topThreshold: CGFloat = 2
        let bottomThreshold: CGFloat = 2
        let atTop = offsetY >= -topThreshold
        let atBottom = maxScroll <= 0 || offsetY <= -(maxScroll + bottomThreshold)
        canPageUp = atTop
        canPageDown = atBottom
    }
}

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ViewportHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
