import SwiftUI
import StudentCore

struct HomeView: View {
    @ObservedObject var vm: AppViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("题库")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.top, 8)

                    LazyVStack(spacing: 12) {
                        ForEach(vm.banks) { bank in
                            Button {
                                Task { await vm.startSession(for: bank) }
                            } label: {
                                BankCardRow(bank: bank)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let error = vm.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.statusDanger)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, AppMetrics.screenHorizontalPadding)
                .padding(.bottom, AppMetrics.tabBarHeight + 90)
            }

            VStack {
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
            .padding(.bottom, AppMetrics.tabBarHeight + 16)
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

    var body: some View {
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
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .appSurface(
            fill: AppTheme.surface,
            stroke: AppTheme.divider
        )
    }
}
