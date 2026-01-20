import SwiftUI

struct PracticeTopBar: View {
    let progress: Double
    let index: Int
    let total: Int
    let onBack: () -> Void
    let onOverview: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("返回")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(AppTheme.surface)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(AppTheme.divider, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(index)/\(total)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Button(action: onOverview) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 14, weight: .semibold))
                        Text("总览")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(AppTheme.surface)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(AppTheme.divider, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            ProgressView(value: progress)
                .tint(AppTheme.accent)
        }
        .padding(.horizontal, AppMetrics.screenHorizontalPadding)
        .padding(.vertical, 10)
        .background(AppTheme.chromeBackground)
        .safeAreaPadding(.top, 6)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.chromeDivider)
                .frame(height: 1)
        }
    }
}
