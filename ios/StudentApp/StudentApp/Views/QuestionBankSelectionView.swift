import Foundation
import StudentCore
import SwiftUI

struct QuestionBankSelectionView: View {
    let banks: [QuestionBank]
    let isLoading: Bool
    let errorMessage: String?
    let onSelect: (QuestionBank) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                header

                if let error = errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.statusDanger)
                        .padding(.top, 4)
                }

                LazyVGrid(columns: columns, spacing: 28) {
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
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 32)

            if isLoading {
                AppTheme.shadowStrong.opacity(0.55)
                    .ignoresSafeArea()
                ProgressView()
                    .tint(AppTheme.accentStrong)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(dayString)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
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
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.dividerStrong, lineWidth: 1)
        )
        .shadow(color: AppTheme.shadowSoft, radius: 10, x: 0, y: 6)
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
