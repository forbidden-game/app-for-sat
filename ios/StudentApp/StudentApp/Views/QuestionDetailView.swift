import SwiftUI
import StudentCore

struct QuestionDetailView: View {
    let question: QuestionResult
    let studentId: String
    @ObservedObject var flowModel: PracticeFlowViewModel
    let onBack: () -> Void

    @State private var coachAttempt: CoachAttemptContext?
    @State private var showCoachChat = false

    private let correctColor = AppTheme.statusSuccess
    private let incorrectColor = AppTheme.statusDanger

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppMetrics.sectionSpacing) {
                    header

                    questionCard

                    if let options = question.options, !options.isEmpty {
                        optionsList(options)
                    } else {
                        numericAnswerCard
                    }

                    explanationSection
                }
                .padding(.horizontal, AppMetrics.screenHorizontalPadding)
                .padding(.top, AppMetrics.screenTopPadding)
                .padding(.bottom, AppMetrics.screenBottomPaddingLarge)
            }

            coachFloatingButton
        }
        .sheet(item: $coachAttempt) { ctx in
            CoachStepSheet(
                coachAttempt: $coachAttempt,
                flowModel: flowModel,
                studentId: studentId,
                attemptId: ctx.id,
                onContinue: {}
            )
        }
        .fullScreenCover(isPresented: $showCoachChat) {
            CoachChatView(studentId: studentId)
        }
    }

    private var header: some View {
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
                        .stroke(AppTheme.dividerStrong, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Question \(question.position)")
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            resultBadge
        }
    }

    private var resultBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: question.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
            Text(question.isCorrect ? "Correct" : "Incorrect")
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(question.isCorrect ? correctColor : incorrectColor)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(AppTheme.surface)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(question.isCorrect ? correctColor.opacity(0.45) : incorrectColor.opacity(0.45), lineWidth: 1)
        )
    }

    private var questionCard: some View {
        Text(question.stem)
            .font(.title3.weight(.semibold))
            .lineSpacing(4)
            .foregroundStyle(AppTheme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppMetrics.cardPadding)
            .appSurface(
                fill: AppTheme.surfaceRaised,
                stroke: AppTheme.dividerStrong,
                cornerRadius: AppMetrics.cardCornerRadius,
                shadowRadius: AppMetrics.cardShadowRadius,
                shadowY: AppMetrics.cardShadowY
            )
    }

    private func optionsList(_ options: [QuestionOption]) -> some View {
        VStack(spacing: AppMetrics.rowSpacing) {
            ForEach(options, id: \.label) { option in
                optionRow(option)
            }
        }
    }

    private func optionRow(_ option: QuestionOption) -> some View {
        let isUserAnswer = question.userAnswer?.displayString == option.label
        let isCorrectAnswer = question.correctAnswer.displayString == option.label
        let showCorrect = isCorrectAnswer
        let showIncorrect = isUserAnswer && !question.isCorrect

        return HStack(spacing: 12) {
            Text(option.label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(labelForeground(isCorrect: showCorrect, isIncorrect: showIncorrect))
                .frame(width: AppMetrics.badgeSize, height: AppMetrics.badgeSize)
                .background(labelBackground(isCorrect: showCorrect, isIncorrect: showIncorrect))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(labelBorder(isCorrect: showCorrect, isIncorrect: showIncorrect), lineWidth: 1)
                )

            Text(option.content)
                .font(.body)
                .lineSpacing(2)
                .foregroundStyle(AppTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            if showCorrect {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(correctColor)
            } else if showIncorrect {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(incorrectColor)
            }
        }
        .padding(.vertical, AppMetrics.rowPaddingVertical)
        .padding(.horizontal, AppMetrics.rowPaddingHorizontal)
        .appSurface(
            fill: AppTheme.surfaceRaised,
            stroke: rowBorder(isCorrect: showCorrect, isIncorrect: showIncorrect),
            showShadow: showCorrect || showIncorrect
        )
    }

    private func labelForeground(isCorrect: Bool, isIncorrect: Bool) -> Color {
        if isCorrect { return .white }
        if isIncorrect { return .white }
        return AppTheme.textSecondary
    }

    private func labelBackground(isCorrect: Bool, isIncorrect: Bool) -> Color {
        if isCorrect { return correctColor }
        if isIncorrect { return incorrectColor }
        return AppTheme.surfaceRaised
    }

    private func labelBorder(isCorrect: Bool, isIncorrect: Bool) -> Color {
        if isCorrect { return correctColor.opacity(0.6) }
        if isIncorrect { return incorrectColor.opacity(0.6) }
        return AppTheme.divider
    }

    private func rowBorder(isCorrect: Bool, isIncorrect: Bool) -> Color {
        if isCorrect { return correctColor.opacity(0.5) }
        if isIncorrect { return incorrectColor.opacity(0.5) }
        return AppTheme.dividerStrong
    }

    private var numericAnswerCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Your answer")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                HStack(spacing: 6) {
                    if let userAnswer = question.userAnswer {
                        Text(userAnswer.displayString)
                            .font(.headline)
                            .foregroundStyle(question.isCorrect ? correctColor : incorrectColor)
                        Image(systemName: question.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(question.isCorrect ? correctColor : incorrectColor)
                    } else {
                        Text("No answer")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }
            }

            Rectangle()
                .fill(AppTheme.divider)
                .frame(height: 1)

            HStack {
                Text("Correct answer")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                HStack(spacing: 6) {
                    Text(question.correctAnswer.displayString)
                        .font(.headline)
                        .foregroundStyle(correctColor)
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(correctColor)
                }
            }
        }
        .padding(AppMetrics.cardPadding)
        .appSurface(
            fill: AppTheme.surfaceRaised,
            stroke: AppTheme.dividerStrong,
            cornerRadius: AppMetrics.cardCornerRadius,
            shadowRadius: AppMetrics.cardShadowRadius,
            shadowY: AppMetrics.cardShadowY
        )
    }

    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: AppMetrics.rowSpacing) {
            Text("Explanation")
                .font(.headline)
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.leading, 4)

            Text(question.explanation)
                .font(.body)
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppMetrics.cardPadding)
                .appSurface(
                    fill: AppTheme.surfaceRaised,
                    stroke: AppTheme.dividerStrong,
                    cornerRadius: AppMetrics.cardCornerRadius,
                    shadowRadius: AppMetrics.cardShadowRadius,
                    shadowY: AppMetrics.cardShadowY
                )
        }
    }

    private var coachFloatingButton: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                Button {
                    handleCoachTap()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))

                        Text("AI老师")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(AppTheme.textOnAccent)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(AppTheme.accent)
                    .clipShape(Capsule())
                    .shadow(color: AppTheme.shadowStrong, radius: 10, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
                .padding(.bottom, 22)
            }
        }
    }

    private func handleCoachTap() {
        if question.isCorrect {
            showCoachChat = true
            return
        }

        guard let attemptId = question.attemptId else {
            showCoachChat = true
            return
        }

        let answer = question.userAnswer?.displayString ?? ""
        coachAttempt = CoachAttemptContext(id: attemptId, questionId: question.questionId, answer: answer)
    }
}
