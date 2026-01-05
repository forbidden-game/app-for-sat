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
            LinearGradient(
                colors: [Color(red: 0.87, green: 0.98, blue: 0.93), Color(red: 0.90, green: 0.95, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Session Overview")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Tap a question to review it")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                                .background(answered ? Color(red: 0.22, green: 0.76, blue: 0.39) : Color(red: 0.94, green: 0.39, blue: 0.39))
                                .foregroundStyle(.white)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let error = submissionError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Button {
                    onSubmit()
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isSubmitting ? "Submitting..." : "Submit")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.22, green: 0.76, blue: 0.39))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
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
