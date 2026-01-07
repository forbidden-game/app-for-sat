import SwiftUI
import StudentCore

struct QuestionDetailView: View {
    let question: QuestionResult
    let onBack: () -> Void

    private let correctColor = Color(red: 0.25, green: 0.72, blue: 0.45)
    private let incorrectColor = Color(red: 0.85, green: 0.35, blue: 0.35)

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    header

                    questionCard

                    if let options = question.options, !options.isEmpty {
                        optionsList(options)
                    } else {
                        numericAnswerCard
                    }

                    explanationSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
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
                .font(.subheadline.weight(.semibold))
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
            .font(.title2.bold())
            .foregroundStyle(AppTheme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppTheme.dividerStrong, lineWidth: 1)
            )
            .shadow(color: AppTheme.shadowStrong, radius: 16, x: 0, y: 8)
    }

    private func optionsList(_ options: [QuestionOption]) -> some View {
        VStack(spacing: 12) {
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
                .font(.headline)
                .foregroundStyle(labelForeground(isCorrect: showCorrect, isIncorrect: showIncorrect))
                .frame(width: 36, height: 36)
                .background(labelBackground(isCorrect: showCorrect, isIncorrect: showIncorrect))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(labelBorder(isCorrect: showCorrect, isIncorrect: showIncorrect), lineWidth: 1)
                )

            Text(option.content)
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

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
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(rowBorder(isCorrect: showCorrect, isIncorrect: showIncorrect), lineWidth: showCorrect || showIncorrect ? 1.5 : 1)
        )
        .shadow(color: AppTheme.shadowSoft, radius: 10, x: 0, y: 6)
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
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.dividerStrong, lineWidth: 1)
        )
        .shadow(color: AppTheme.shadowStrong, radius: 16, x: 0, y: 8)
    }

    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Explanation")
                .font(.headline)
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.leading, 4)

            Text(question.explanation)
                .font(.body)
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(AppTheme.surfaceRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppTheme.dividerStrong, lineWidth: 1)
                )
                .shadow(color: AppTheme.shadowStrong, radius: 16, x: 0, y: 8)
        }
    }
}
