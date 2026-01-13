import SwiftUI
import StudentCore

struct CoachReportsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: CoachReportsViewModel

    init(studentId: String) {
        _vm = StateObject(wrappedValue: CoachReportsViewModel(studentId: studentId))
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 12) {
                header

                kindPicker

                content
            }
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .task {
            await vm.load()
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

            Text("进展报告")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
    }

    private var kindPicker: some View {
        Picker("Report Kind", selection: $vm.selectedKind) {
            ForEach(CoachReportsViewModel.ReportKind.allCases) { kind in
                Text(kind.title).tag(kind)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .onChange(of: vm.selectedKind) { _, newValue in
            Task { await vm.select(newValue) }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 14) {
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
                } else if vm.reports.isEmpty {
                    emptyState
                } else {
                    ForEach(vm.reports) { report in
                        ReportCard(report: report)
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
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)

            Text("暂时还没有进展报告")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textMuted)

            Text("完成更多练习后会自动生成周报/月报")
                .font(.footnote)
                .foregroundStyle(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }
}

private struct ReportCard: View {
    let report: StudentReport

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM/dd"
        return formatter
    }()

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()

    var body: some View {
        let plan = ReportPlan(from: report.plan)

        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                Text("生成时间：\(timestamp)")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textMuted)
            }

            Text(report.summary)
                .font(.body)
                .foregroundStyle(AppTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if !plan.focusAreas.isEmpty {
                sectionTitle("本期关注")
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(plan.focusAreas) { item in
                        bullet(item)
                    }
                }
            }

            if !plan.nextSteps.isEmpty {
                sectionTitle("下一步")
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(plan.nextSteps) { item in
                        bullet(item)
                    }
                }
            }

            if !plan.pace.isEmpty {
                sectionTitle("节奏建议")
                Text(plan.pace)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
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

    private var title: String {
        let kind = report.periodKind == "monthly" ? "月报" : "周报"
        let start = Self.dateFormatter.string(from: report.periodStart)
        let end = Self.dateFormatter.string(from: report.periodEnd)
        return "\(kind) \(start) - \(end)"
    }

    private var timestamp: String {
        Self.timestampFormatter.string(from: report.createdAt)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.textSecondary)
    }

    private func bullet(_ item: ReportPlan.Item) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("• \(item.title)")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textPrimary)

            if let detail = item.detail, !detail.isEmpty {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
    }
}

private struct ReportPlan {
    struct Item: Identifiable {
        let id = UUID()
        let title: String
        let detail: String?
    }

    let focusAreas: [Item]
    let nextSteps: [Item]
    let pace: String

    init(from value: JSONValue) {
        guard case .object(let dict) = value else {
            focusAreas = []
            nextSteps = []
            pace = ""
            return
        }

        focusAreas = Self.parseItems(dict["focus_areas"], titleKey: "topic", detailKey: "reason")
        nextSteps = Self.parseItems(dict["next_steps"], titleKey: "action", detailKey: "why")
        pace = Self.stringValue(dict["pace"]) ?? ""
    }

    private static func parseItems(
        _ value: JSONValue?,
        titleKey: String,
        detailKey: String
    ) -> [Item] {
        guard case .array(let items) = value else { return [] }

        return items.compactMap { item in
            guard case .object(let dict) = item else { return nil }
            guard let title = stringValue(dict[titleKey]), !title.isEmpty else { return nil }
            let detail = stringValue(dict[detailKey])
            return Item(title: title, detail: detail)
        }
    }

    private static func stringValue(_ value: JSONValue?) -> String? {
        guard case .string(let text) = value else { return nil }
        return text
    }
}
