import SwiftUI
import StudentCore

struct SessionOverviewView: View {
    let session: PracticeSession
    let answers: [String: String]
    let isSubmitting: Bool
    let submissionError: String?
    let onSelectQuestion: (Int) -> Void
    let onSubmit: () -> Void

    private let columns = [GridItem(.adaptive(minimum: AppMetrics.gridItemMinimum), spacing: AppMetrics.gridSpacing)]

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: AppMetrics.sectionSpacing) {
                Text("Session Overview")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Tap a question to review it")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: columns, spacing: AppMetrics.gridSpacing) {
                    ForEach(Array(session.questions.enumerated()), id: \.offset) { index, question in
                        let answered = isAnswered(question)
                        Button {
                            onSelectQuestion(index)
                        } label: {
                            Text("\(index + 1)")
                                .font(.headline)
                                .frame(width: AppMetrics.gridButtonSize, height: AppMetrics.gridButtonSize)
                                .background(answered ? AppTheme.accentStrong : AppTheme.surfaceRaised)
                                .foregroundStyle(answered ? AppTheme.textOnAccent : AppTheme.textPrimary)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(AppTheme.divider, lineWidth: 1)
                                )
                                .shadow(color: AppTheme.shadowSoft, radius: AppMetrics.rowShadowRadius, x: 0, y: AppMetrics.rowShadowY)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let error = submissionError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.statusDanger)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Button {
                    onSubmit()
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .tint(AppTheme.textMuted)
                        }
                        Text(isSubmitting ? "Submitting..." : "Submit")
                            .font(.headline)
                    }
                    .foregroundStyle(isSubmitting ? AppTheme.textMuted : AppTheme.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppMetrics.primaryButtonPaddingVertical)
                    .background(isSubmitting ? AppTheme.surfacePressed : AppTheme.accentStrong)
                    .clipShape(RoundedRectangle(cornerRadius: AppMetrics.rowCornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppMetrics.rowCornerRadius, style: .continuous)
                            .stroke(isSubmitting ? AppTheme.divider : AppTheme.accent, lineWidth: 1)
                    )
                    .shadow(color: isSubmitting ? AppTheme.shadowSoft : AppTheme.shadowStrong, radius: AppMetrics.cardShadowRadius, x: 0, y: AppMetrics.cardShadowY)
                }
                .disabled(isSubmitting)
            }
            .padding(.horizontal, AppMetrics.screenHorizontalPadding)
            .padding(.top, AppMetrics.screenTopPadding)
            .padding(.bottom, AppMetrics.screenBottomPadding)
        }
    }

    private func isAnswered(_ question: Question) -> Bool {
        guard let value = answers[question.id] else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
