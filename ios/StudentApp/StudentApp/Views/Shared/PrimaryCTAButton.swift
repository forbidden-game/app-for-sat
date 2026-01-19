import SwiftUI

struct PrimaryCTAButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(AppTheme.textOnAccent)
                } else {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.textOnAccent)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(AppTheme.ctaFillGradient)
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.rowCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.rowCornerRadius, style: .continuous)
                    .stroke(AppTheme.ctaStrokeGradient, lineWidth: 1)
            )
            .shadow(color: AppTheme.shadowSoft, radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.6 : 1)
    }
}
