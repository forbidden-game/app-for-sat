import Combine
import Foundation
import StudentCore
import SwiftUI

struct QuestionBankSelectionView: View {
    let banks: [QuestionBank]
    let isLoading: Bool
    let errorMessage: String?
    let onSelect: (QuestionBank) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: AppMetrics.gridSpacingWide),
        GridItem(.flexible(), spacing: AppMetrics.gridSpacingWide)
    ]

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: AppMetrics.sectionSpacingLarge) {
                header

                if let error = errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.statusDanger)
                        .padding(.top, 4)
                }

                LazyVGrid(columns: columns, spacing: AppMetrics.gridSpacingWide) {
                    ForEach(banks) { bank in
                        Button {
                            onSelect(bank)
                        } label: {
                            bankCell(bank)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, AppMetrics.screenHorizontalPadding)
            .padding(.top, AppMetrics.screenTopPadding)
            .padding(.bottom, AppMetrics.screenBottomPaddingLarge)

            if isLoading {
                AppTheme.shadowStrong.opacity(0.55)
                    .ignoresSafeArea()
                ProgressView()
                    .tint(AppTheme.accentStrong)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppMetrics.headerSpacing) {
            Text(dayString)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Text(dateString)
                .font(.footnote)
                .foregroundStyle(AppTheme.textMuted)
        }
        .padding(.top, 8)
    }

    private func bankCell(_ bank: QuestionBank) -> some View {
        VStack(spacing: 12) {
            Image(systemName: bank.icon ?? "square.grid.2x2.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(AppTheme.accentStrong)

            VStack(spacing: 4) {
                Text(bank.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)

                if let subtitle = bank.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppMetrics.cardPadding)
        .appSurface(
            fill: AppTheme.surface,
            stroke: AppTheme.dividerStrong,
            cornerRadius: AppMetrics.cardCornerRadius,
            shadowRadius: AppMetrics.cardShadowRadius,
            shadowY: AppMetrics.cardShadowY
        )
    }

    private var dayString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd"
        return formatter.string(from: Date())
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM d, EEEE"
        return formatter.string(from: Date())
    }
}
