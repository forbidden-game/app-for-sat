import SwiftUI

struct SessionSummaryView: View {
    let total: Int
    let correct: Int

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: AppMetrics.sectionSpacing) {
                Text("Session Complete")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Score: \(correct)/\(total)")
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}
