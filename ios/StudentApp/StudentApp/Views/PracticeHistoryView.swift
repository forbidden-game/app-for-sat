import SwiftUI
import StudentCore

struct PracticeHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    let banks: [QuestionBank]
    let studentId: String
    let showsHeader: Bool

    @StateObject private var vm = PracticeHistoryViewModel()
    @StateObject private var behaviorVM = StudyBehaviorViewModel()
    @State private var selectedSession: SessionHistoryItem?

    init(banks: [QuestionBank], studentId: String, showsHeader: Bool = true) {
        self.banks = banks
        self.studentId = studentId
        self.showsHeader = showsHeader
    }

    var body: some View {
        ZStack {
            if showsHeader {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()
            } else {
                Color.clear
            }

            VStack(spacing: 12) {
                if showsHeader {
                    header
                }

                filterBar

                content
            }
            .padding(.top, showsHeader ? 12 : 0)
            .padding(.bottom, 12)
        }
        .task {
            await vm.load()
        }
        .task {
            await behaviorVM.load(windowDays: 7)
        }
        .onChange(of: vm.selectedRange) { _, _ in
            Task { await vm.load() }
        }
        .onChange(of: vm.selectedBankId) { _, _ in
            Task { await vm.load() }
        }
        .sheet(item: $selectedSession) { item in
            HistorySessionDetailView(sessionId: item.sessionId, studentId: studentId)
        }
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppTheme.divider, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            Text("做题记录")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
    }

    private var filterBar: some View {
        VStack(spacing: 10) {
            Picker("Range", selection: $vm.selectedRange) {
                ForEach(PracticeHistoryViewModel.RangeFilter.allCases) { range in
                    Text(range.title).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            HStack {
                Text("题库")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)

                Spacer()

                Picker("题库", selection: $vm.selectedBankId) {
                    Text("全部题库").tag(String?.none)
                    ForEach(banks) { bank in
                        Text(bank.title).tag(Optional(bank.id))
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .appSurface(fill: AppTheme.surfaceRaised, stroke: AppTheme.divider)
            .padding(.horizontal, 16)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 14) {
                if behaviorVM.isLoading {
                    ProgressView()
                        .tint(AppTheme.accentStrong)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else if let behavior = behaviorVM.behavior {
                    StudyBehaviorCard(behavior: behavior)
                } else if let behaviorError = behaviorVM.errorMessage {
                    Text(behaviorError)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.statusDanger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.statusDanger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                }

                if vm.isLoading {
                    ProgressView()
                        .tint(AppTheme.accentStrong)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                } else if vm.items.isEmpty {
                    emptyState
                } else {
                    ForEach(vm.items) { item in
                        Button {
                            selectedSession = item
                        } label: {
                            SessionHistoryCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .refreshable {
            await vm.refresh()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)

            Text("暂无做题记录")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textMuted)

            Text("完成练习后会在这里展示")
                .font(.footnote)
                .foregroundStyle(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }
}

private struct SessionHistoryCard: View {
    let item: SessionHistoryItem

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(bankTitle)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Text(Self.dateFormatter.string(from: item.createdAt))
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textMuted)
            }

            HStack(spacing: 16) {
                metric(title: "用时", value: durationText)
                metric(title: "正确率", value: accuracyText)
                metric(title: "错题数", value: "\(item.incorrectCount)")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appSurface(
            fill: AppTheme.surfaceRaised,
            stroke: AppTheme.dividerStrong,
            cornerRadius: 18,
            shadowRadius: 10,
            shadowY: 6
        )
    }

    private var bankTitle: String {
        let title = item.bankTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        return title?.isEmpty == false ? title! : "未命名题库"
    }

    private var durationText: String {
        let totalMinutes = max(Int(round(Double(item.durationMs) / 60000.0)), 0)
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            if minutes == 0 {
                return "\(hours)小时"
            }
            return "\(hours)小时\(minutes)分"
        }
        return "\(totalMinutes)分钟"
    }

    private var accuracyText: String {
        let attempts = max(item.attempts, 0)
        guard attempts > 0 else { return "--" }
        let accuracy = Double(item.correctCount) / Double(attempts) * 100
        return String(format: "%.0f%%", accuracy)
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textMuted)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
    }
}
