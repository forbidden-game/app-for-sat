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
                                .foregroundStyle(answered ? Color.black : AppTheme.textPrimary)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(AppTheme.divider, lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let error = submissionError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(Color(red: 0.92, green: 0.45, blue: 0.45))
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Button {
                    onSubmit()
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .tint(.black)
                        }
                        Text(isSubmitting ? "Submitting..." : "Submit")
                            .font(.headline)
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.accentStrong)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 6)
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
