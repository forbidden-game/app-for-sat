import SwiftUI
import StudentCore
#if canImport(UIKit)
import UIKit
#endif

struct QuestionFeedView: View {
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

    var body: some View {
        let total = vm.session.questions.count

        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            PagingScrollView(pageCount: total + 1, currentPage: $currentPage) { index in
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

            VStack(spacing: 20) {
                header(progress: progress, index: index + 1, total: total, question: question)

                questionCard(text: question.stem)

                if let options = question.options, !options.isEmpty {
                    optionsGrid(options, questionId: question.id, questionIndex: index)
                } else {
                    freeResponseField(questionId: question.id, questionIndex: index)
                }

                Spacer()

            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .scrollTransition(.animated(.spring(response: 0.35, dampingFraction: 0.9))) { content, phase in
                content
                    .scaleEffect(1 - abs(phase.value) * 0.05)
                    .opacity(1 - abs(phase.value) * 0.3)
            }
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
        VStack(spacing: 10) {
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
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            ProgressView(value: progress)
                .tint(AppTheme.accent)
        }
    }

    // MARK: - Question Card

    private func questionCard(text: String) -> some View {
        Text(text)
            .font(.title2.bold())
            .foregroundStyle(AppTheme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppTheme.dividerStrong, lineWidth: 1)
            )
            .shadow(color: AppTheme.shadowStrong, radius: 14, x: 0, y: 8)
    }

    // MARK: - Options Grid

    private func optionsGrid(_ options: [QuestionOption], questionId: String, questionIndex: Int) -> some View {
        VStack(spacing: 12) {
            ForEach(options, id: \.label) { option in
                optionButton(option, questionId: questionId, questionIndex: questionIndex)
            }
        }
    }

    private func optionButton(_ option: QuestionOption, questionId: String, questionIndex: Int) -> some View {
        let isCurrentQuestion = questionIndex == vm.currentIndex
        let isSelected = isCurrentQuestion && selectedOption == option.label
        let isJustSelected = isCurrentQuestion && showFeedback && isSelected
        
        return Button {
            guard isCurrentQuestion, !showFeedback else { return }
            selectedOption = option.label
            triggerSelectionHaptic()
            withAnimation(.easeInOut(duration: 0.15)) {
                showFeedback = true
            }
            recordAnswer(option.label, questionId: questionId)
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                showFeedback = false
                advanceAfterAnswer()
            }
        } label: {
            HStack(spacing: 12) {
                Text(option.label)
                    .font(.headline)
                    .foregroundStyle(isJustSelected ? AppTheme.textOnAccent : (isSelected ? AppTheme.textOnAccent : AppTheme.textSecondary))
                    .frame(width: 36, height: 36)
                    .background(
                        isJustSelected ? AppTheme.statusSuccess : (isSelected ? AppTheme.accentStrong : AppTheme.surfaceRaised)
                    )
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(isJustSelected ? AppTheme.statusSuccess : (isSelected ? AppTheme.accent : AppTheme.dividerStrong), lineWidth: isJustSelected ? 2 : 1)
                    )

                Text(option.content)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isJustSelected ? AppTheme.surfacePressed : (isSelected ? AppTheme.surfacePressed : AppTheme.surfaceRaised))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isJustSelected ? AppTheme.statusSuccess : (isSelected ? AppTheme.accent : AppTheme.dividerStrong), lineWidth: isJustSelected ? 2 : 1)
            )
            .shadow(color: AppTheme.shadowSoft, radius: 10, x: 0, y: 6)
            .scaleEffect(isJustSelected ? 0.97 : 1.0)
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
                .foregroundStyle(showingFeedback ? AppTheme.statusSuccess : AppTheme.accent)

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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(showingFeedback ? AppTheme.surfacePressed : AppTheme.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(showingFeedback ? AppTheme.statusSuccess : (isEnabled ? AppTheme.dividerStrong : AppTheme.divider), lineWidth: showingFeedback ? 2 : 1)
        )
        .shadow(color: AppTheme.shadowSoft, radius: 10, x: 0, y: 6)
        .scaleEffect(showingFeedback ? 0.97 : 1.0)
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
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            showFeedback = false
            advanceAfterAnswer()
        }
    }

    private func recordAnswer(_ value: String, questionId: String) {
        answers[questionId] = value
        let question = vm.session.questions.first { $0.id == questionId }
        if let question {
            flowModel.submitAnswer(question: question, answer: value)
        }
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
    }

    private func loadAnswer(for question: Question) {
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
