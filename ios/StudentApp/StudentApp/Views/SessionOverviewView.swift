import SwiftUI
import StudentCore

struct SessionOverviewView: View {
    let session: PracticeSession
    let answers: [String: String]
    let isSubmitting: Bool
    let submissionError: String?
    let onSelectQuestion: (Int) -> Void
    let onSubmit: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 56), spacing: 12)]

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Session Overview")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Tap a question to review it")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(session.questions.enumerated()), id: \.offset) { index, question in
                        let answered = isAnswered(question)
                        Button {
                            onSelectQuestion(index)
                        } label: {
                            Text("\(index + 1)")
                                .font(.headline)
                                .frame(width: 48, height: 48)
                                .background(answered ? AppTheme.accentStrong : AppTheme.surfaceRaised)
                                .foregroundStyle(answered ? AppTheme.textOnAccent : AppTheme.textPrimary)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(AppTheme.divider, lineWidth: 1)
                                )
                                .shadow(color: AppTheme.shadowSoft, radius: 6, x: 0, y: 3)
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
                    .padding(.vertical, 14)
                    .background(isSubmitting ? AppTheme.surfacePressed : AppTheme.accentStrong)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSubmitting ? AppTheme.divider : AppTheme.accent, lineWidth: 1)
                    )
                    .shadow(color: isSubmitting ? AppTheme.shadowSoft : AppTheme.shadowStrong, radius: 10, x: 0, y: 6)
                }
                .disabled(isSubmitting)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }

    private func isAnswered(_ question: Question) -> Bool {
        guard let value = answers[question.id] else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
