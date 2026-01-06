import SwiftUI
import StudentCore

struct SessionResultView: View {
    let result: SessionResult
    let onSelectQuestion: (QuestionResult) -> Void
    let onDismiss: () -> Void

    @State private var appeared = false

    private var percentage: Double {
        guard result.totalQuestions > 0 else { return 0 }
        return Double(result.correctCount) / Double(result.totalQuestions) * 100
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                scoreHeader
                    .padding(.top, 32)
                    .padding(.bottom, 28)

                resultsSection

                doneButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
    }

    private var scoreHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(AppTheme.divider, lineWidth: 6)
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0, to: appeared ? percentage / 100 : 0)
                    .stroke(
                        AppTheme.accentStrong,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8).delay(0.2), value: appeared)

                VStack(spacing: 4) {
                    Text("\(result.correctCount)/\(result.totalQuestions)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(String(format: "%.0f%%", percentage))
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.8)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3), value: appeared)
            }
            .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 8)

            Text("Session Complete")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.5), value: appeared)
        }
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Results")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 20)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.4), value: appeared)

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(Array(result.questions.enumerated()), id: \.element.id) { index, questionResult in
                        questionRow(questionResult, index: index)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.8)
                                    .delay(0.5 + Double(index) * 0.05),
                                value: appeared
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func questionRow(_ questionResult: QuestionResult, index: Int) -> some View {
        Button {
            onSelectQuestion(questionResult)
        } label: {
            HStack(spacing: 14) {
                Text("\(questionResult.position)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textMuted)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.surfaceRaised)
                    .clipShape(Circle())

                Text(questionResult.stem)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: questionResult.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(questionResult.isCorrect ? Color(red: 0.4, green: 0.78, blue: 0.5) : Color(red: 0.92, green: 0.45, blue: 0.45))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.divider, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var doneButton: some View {
        Button {
            onDismiss()
        } label: {
            Text("Done")
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.accentStrong)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.4).delay(0.7), value: appeared)
    }
}
