import SwiftUI

struct SessionSummaryView: View {
    let total: Int
    let correct: Int

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Text("Session Complete")
                    .font(.title)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Score: \(correct)/\(total)")
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}
