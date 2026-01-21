import SwiftUI
import StudentCore

struct HomeView: View {
    @ObservedObject var vm: AppViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppMetrics.sectionSpacing) {
                    Text("题库")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.top, AppMetrics.headerSpacing)

                    LazyVStack(spacing: AppMetrics.rowSpacing) {
                        ForEach(vm.banks) { bank in
                            BankCardRow(bank: bank) {
                                Task { await vm.startSession(for: bank) }
                            }
                        }
                    }

                    if let error = vm.errorMessage {
                        // ✅ Using ErrorCard component
                        ErrorCard(message: error) {
                            vm.dismissError()
                        }
                        .padding(.top, AppMetrics.rowSpacing)
                    }
                }
                .padding(.horizontal, AppMetrics.screenHorizontalPadding)
                .padding(.bottom, AppMetrics.tabBarHeight + 90)
            }

            VStack {
                // ✅ Using PrimaryCTAButton with unified styling
                PrimaryCTAButton(
                    title: "练习",
                    isLoading: vm.isStartingRecommended,
                    isDisabled: vm.isLoading || vm.isStartingRecommended,
                    action: {
                        Task { await vm.startRecommendedSession() }
                    }
                )
            }
            .padding(.horizontal, AppMetrics.screenHorizontalPadding)
            .padding(.bottom, AppMetrics.tabBarHeight + AppMetrics.sectionSpacing)
        }
        .overlay {
            if vm.isLoading {
                AppTheme.shadowStrong.opacity(0.35)
                    .ignoresSafeArea()
                ProgressView()
                    .tint(AppTheme.accentStrong)
            }
        }
    }
}

private struct BankCardRow: View {
    let bank: QuestionBank
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: bank.icon ?? "square.grid.2x2.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.accentStrong)
                    .frame(width: 42, height: 42)
                    .background(AppTheme.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppTheme.divider, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(bank.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    if let subtitle = bank.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)
            }
            .padding(.vertical, AppMetrics.rowPaddingVertical)
            .padding(.horizontal, AppMetrics.rowPaddingHorizontal)
            .appSurface(
                fill: AppTheme.surface,
                stroke: AppMetrics.strokeWidthThin
            )
        }
        .buttonStyle(.plain)
    }
}
