import SwiftUI
import UIKit
import StudentCore

struct QuestionContentView: View {
    let question: Question
    let index: Int
    let total: Int
    let questionProvider: (Int) -> Question?
    @ObservedObject var state: QuestionFeedState
    @ObservedObject var store: InMemoryAnswerStore
    @ObservedObject var submission: AnswerSubmissionCoordinator
    @Binding var returnToOverviewOnAnswer: Bool
    let headerTitle: String?
    let onBack: () -> Void
    let onShowOverview: () -> Void
    let onSubmissionError: (Error) -> Void
    let outerPan: UIPanGestureRecognizer?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    @State private var layout: QuestionBodyLayout = .short
    @State private var layoutReady = false
    @State private var layoutTask: Task<Void, Never>?
    @State private var prefetchTask: Task<Void, Never>?
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
        .onChange(of: question.id) { _, _ in
            resetLayout()
        }
        .onChange(of: colorScheme) { _, _ in
            resetLayout()
        }
        .onChange(of: displayScale) { _, _ in
            resetLayout()
        }
        .onDisappear {
            layoutTask?.cancel()
            layoutTask = nil
            prefetchTask?.cancel()
            prefetchTask = nil
        }
    }

    private func bodyLayout() -> some View {
        switch layout {
        case .short:
            return AnyView(shortBodyLayout())
        case .long(let stemPages, let answerPages):
            return AnyView(longBodyLayout(stemPages: stemPages, answerPages: answerPages))
        }
    }

    private func shortBodyLayout() -> some View {
        VStack(spacing: AppMetrics.sectionSpacing) {
            questionCard(text: question.stem)
            QuestionAnswerContentView(
                question: question,
                answerPage: nil,
                questionIndex: index,
                total: total,
                state: state,
                store: store,
                submission: submission,
                returnToOverviewOnAnswer: $returnToOverviewOnAnswer,
                onShowOverview: onShowOverview,
                onSubmissionError: onSubmissionError
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func longBodyLayout(stemPages: [String], answerPages: [QuestionAnswerPage]) -> some View {
        let pages = stemPages.map { QuestionHorizontalPage.stem($0) } + answerPages.map { .answer($0) }
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
                    case .answer(let answerPage):
                        return AnyView(answerPageView(answerPage: answerPage, questionId: question.id, questionIndex: index))
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

    private func answerPageView(
        answerPage: QuestionAnswerPage,
        questionId: String,
        questionIndex: Int
    ) -> some View {
        QuestionAnswerContentView(
            question: question,
            answerPage: answerPage,
            questionIndex: questionIndex,
            total: total,
            state: state,
            store: store,
            submission: submission,
            returnToOverviewOnAnswer: $returnToOverviewOnAnswer,
            onShowOverview: onShowOverview,
            onSubmissionError: onSubmissionError
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
        prefetchTask?.cancel()
        prefetchTask = nil
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

        layoutTask?.cancel()
        layoutTask = nil

        if let cached = QuestionLayoutEngine.shared.cachedLayout(
            question: question,
            size: size,
            colorScheme: colorScheme,
            displayScale: displayScale
        ) {
            applyLayout(cached)
            schedulePrefetchNeighbors(size: size)
            return
        }

        layoutReady = false

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
                applyLayout(result)
                schedulePrefetchNeighbors(size: size)
            }
        }
    }

    private func applyLayout(_ result: QuestionBodyLayout) {
        layout = result
        layoutReady = true
        if case .long(let stemPages, let answerPages) = result {
            let pageCount = stemPages.count + answerPages.count
            state.setStemPageCount(pageCount, for: question.id)
            let clamped = clampPageIndex(state.stemPage(for: question.id), pageCount: pageCount)
            if clamped != state.stemPage(for: question.id) {
                state.setStemPage(clamped, for: question.id)
            }
        } else {
            state.setStemPageCount(1, for: question.id)
            state.setStemPage(0, for: question.id)
        }
    }

    private func schedulePrefetchNeighbors(size: CGSize) {
        guard index == state.currentIndex else { return }
        prefetchTask?.cancel()
        prefetchTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            await prefetchNeighbor(at: index - 1, size: size)
            await prefetchNeighbor(at: index + 1, size: size)
        }
    }

    private func prefetchNeighbor(at index: Int, size: CGSize) async {
        guard let neighbor = questionProvider(index) else { return }
        await QuestionLayoutEngine.shared.prefetch(
            question: neighbor,
            size: size,
            colorScheme: colorScheme,
            displayScale: displayScale,
            textColor: AppTheme.textPrimary
        )
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
                    .accessibilityIdentifier("question_back_\(question.id)")

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
                        .accessibilityIdentifier("question_index_\(question.id)")
                }

                Text(resolvedHeaderTitle(for: question))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .accessibilityIdentifier("question_title_\(question.id)")
            }

            ProgressView(value: progress)
                .tint(AppTheme.accent)
                .accessibilityIdentifier("question_progress_\(question.id)")

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
        let status = isAnswered ? submission.status(for: question.id) : .idle

        let title: String
        let icon: String
        let fill: Color
        let stroke: Color
        let textColor: Color

        switch status {
        case .submitting:
            title = "Saving..."
            icon = "arrow.triangle.2.circlepath"
            fill = AppTheme.accentSoft
            stroke = AppTheme.accentStrong
            textColor = AppTheme.accentStrong
        case .failed:
            title = "Failed · Tap to retry"
            icon = "exclamationmark.triangle.fill"
            fill = AppTheme.statusDanger.opacity(0.15)
            stroke = AppTheme.statusDanger
            textColor = AppTheme.statusDanger
        case .idle:
            title = isAnswered ? "Answered · Editable" : "Not answered"
            icon = isAnswered ? "checkmark.seal.fill" : "circle"
            fill = isAnswered ? AppTheme.accentSoft : AppTheme.surfaceRaised
            stroke = isAnswered ? AppTheme.accentStrong : AppTheme.divider
            textColor = isAnswered ? AppTheme.accentStrong : AppTheme.textMuted
        }

        let pill = HStack(spacing: 6) {
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
        .accessibilityIdentifier("question_status_\(question.id)")

        return Group {
            if case .failed = status, isAnswered {
                Button {
                    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    submission.submit(
                        question: question,
                        answer: trimmed,
                        questionId: question.id,
                        onSuccess: { _ in },
                        onFailure: { error in
                            onSubmissionError(error)
                        }
                    )
                } label: {
                    pill
                }
                .buttonStyle(.plain)
            } else {
                pill
            }
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

