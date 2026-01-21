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
                    .padding(.top, AppMetrics.sectionSpacingLarge)
                    .padding(.bottom, AppMetrics.sectionSpacingLarge)

                resultsSection

                doneButton
                    .padding(.horizontal, AppMetrics.screenHorizontalPadding)
                    .padding(.bottom, AppMetrics.screenBottomPadding)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: AppMetrics.animationDurationVerySlow)) {
                appeared = true
            }
        }
    }

    private var scoreHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                // ✅ Unified using AppMetrics.circleStrokeWidth
                Circle()
                    .stroke(AppTheme.divider, lineWidth: AppMetrics.circleStrokeWidth)
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0, to: appeared ? percentage / 100 : 0)
                    .stroke(
                        AppTheme.accentStrong,
                        style: StrokeStyle(
                            lineWidth: AppMetrics.circleStrokeWidth,
                            lineCap: .round
                        )
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    // ✅ Unified using AppMetrics.animationDurationSlow
                    .animation(
                        .easeOut(duration: AppMetrics.animationDurationSlow).delay(0.2),
                        value: appeared
                    )

                VStack(spacing: 4) {
                    // ✅ Using AppFont.scoreLarge
                    Text("\(result.correctCount)/\(result.totalQuestions)")
                        .font(AppFont.scoreLarge)
                        .foregroundStyle(AppTheme.textPrimary)

                    // ✅ Using AppFont.scoreMedium
                    Text(String(format: "%.0f%%", percentage))
                        .font(AppFont.scoreMedium)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.8)
                .animation(
                    AppMetrics.springAnimation.delay(0.3),
                    value: appeared
                )
            }
            // ✅ Unified using AppMetrics.shadowRadiusLarge
            .shadow(
                color: AppTheme.shadowStrong,
                radius: AppMetrics.shadowRadiusLarge,
                x: 0,
                y: AppMetrics.shadowYLarge
            )

            // ✅ Unified using AppMetrics.animationDurationMedium
            Text("Session Complete")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .opacity(appeared ? 1 : 0)
                .animation(
                    .easeOut(duration: AppMetrics.animationDurationMedium).delay(0.5),
                    value: appeared
                )
        }
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: AppMetrics.sectionSpacing) {
            Text("Your Results")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, AppMetrics.screenHorizontalPadding)
                .opacity(appeared ? 1 : 0)
                .animation(
                    .easeOut(duration: AppMetrics.animationDurationMedium).delay(0.4),
                    value: appeared
                )

            ScrollView {
                VStack(spacing: AppMetrics.rowSpacing) {
                    ForEach(Array(result.questions.enumerated()), id: \.element.id) { index, questionResult in
                        questionRow(questionResult, index: index)
                            .opacity(appeared ? 1 : 0)
                            .animation(
                                .easeOut(duration: AppMetrics.animationDurationMedium)
                                    .delay(0.5 + Double(index) * 0.05),
                                value: appeared
                            )
                    }
                }
                .padding(.horizontal, AppMetrics.screenHorizontalPadding)
                .padding(.bottom, AppMetrics.screenBottomPadding)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func questionRow(_ questionResult: QuestionResult, index: Int) -> some View {
        Button {
            onSelectQuestion(questionResult)
        } label: {
            HStack(spacing: 14) {
                // ✅ Using IndexBadge component
                IndexBadge(index: questionResult.position, isCorrect: nil)

                MathTextView(text: questionResult.stem, style: .body)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // ✅ Using StatusIcon component
                StatusIcon(isSuccess: questionResult.isCorrect)
            }
            .padding(.vertical, AppMetrics.rowPaddingVertical)
            .padding(.horizontal, AppMetrics.rowPaddingHorizontal)
            .appSurface(
                fill: AppTheme.surface,
                stroke: AppTheme.divider
            )
        }
        .buttonStyle(.plain)
    }

    private var doneButton: some View {
        // ✅ Using SecondaryCTAButton component
        SecondaryCTAButton(title: "Done", isLoading: false) {
            onDismiss()
        }
        .opacity(appeared ? 1 : 0)
        .animation(
            .easeOut(duration: AppMetrics.animationDurationMedium).delay(0.7),
            value: appeared
        )
    }
}
