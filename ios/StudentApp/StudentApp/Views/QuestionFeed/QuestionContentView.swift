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

    // Resets when the question becomes active so the user sees time spent on the current question.
    @State private var questionStartedAt: Date = .now

    var body: some View {
        let progress = total > 0 ? Double(index + 1) / Double(total) : 0
        let isCurrentQuestion = index == state.currentIndex

        VStack(spacing: AppMetrics.sectionSpacing) {
            PracticeTopBar(
                progress: progress,
                index: index + 1,
                total: total,
                onBack: onBack,
                onOverview: onShowOverview
            )

            if isCurrentQuestion {
                HStack {
                    Spacer()
                    QuestionTimerPill(questionStartedAt: questionStartedAt, bankStartedAt: state.sessionStartedAt)
                }
                .padding(.horizontal, AppMetrics.screenHorizontalPadding)
            }

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
            .padding(.horizontal, AppMetrics.screenHorizontalPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.bottom, AppMetrics.pageBottomPadding)
        .onAppear {
            if index == state.currentIndex {
                questionStartedAt = .now
            }
        }
        .onChange(of: question.id) { _, _ in
            questionStartedAt = .now
            resetLayout()
        }
        .onChange(of: state.currentIndex) { _, newIndex in
            if newIndex == index {
                questionStartedAt = .now
            }
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

}

private struct QuestionTimerPill: View {
    let questionStartedAt: Date
    let bankStartedAt: Date

    var body: some View {
        let start = min(questionStartedAt, bankStartedAt)
        TimelineView(.periodic(from: start, by: 1.0)) { timeline in
            let now = timeline.date
            let questionText = Self.formatElapsed(from: questionStartedAt, now: now)
            let bankText = Self.formatElapsed(from: bankStartedAt, now: now)
            let text = "\(questionText)/\(bankText)"

            Text(text)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(AppTheme.surface.opacity(0.9))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(AppTheme.divider, lineWidth: 1)
                )
                .accessibilityLabel("Question time \(questionText), total time \(bankText)")
        }
    }

    private static func formatElapsed(from start: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%02d:%02d", minutes, remainder)
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

