import SwiftUI
import StudentCore

struct StudyBehaviorCard: View {
    let behavior: StudyBehavior

    fileprivate static let dateParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    fileprivate static let dateLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: AppMetrics.sectionSpacing) {
            header
            metrics
            StudyBehaviorStrip(daily: Array(behavior.daily.suffix(7)))
            drivers
        }
        .padding(AppMetrics.cardPadding)
        .appSurface(
            fill: AppTheme.surfaceRaised,
            stroke: AppTheme.dividerStrong,
            cornerRadius: AppMetrics.cardCornerRadius,
            shadowRadius: AppMetrics.shadowRadiusCard,
            shadowY: AppMetrics.shadowYCard
        )
    }

    private var header: some View {
        HStack {
            Text("学习习惯")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            Text(behavior.state.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textOnAccent)
                .padding(.vertical, AppMetrics.headerSpacing / 2)
                .padding(.horizontal, AppMetrics.rowPaddingHorizontal / 2)
                .background(stateColor(behavior.state.label))
                .clipShape(Capsule())
        }
    }

    private var metrics: some View {
        HStack(spacing: AppMetrics.gridSpacing) {
            BehaviorMetric(
                title: "用时",
                value: String(format: "%.1f min", behavior.metrics.minutes),
                delta: formatDelta(value: behavior.metrics.minutesDelta, suffix: " min")
            )
            BehaviorMetric(
                title: "正确率",
                value: formatPercent(behavior.metrics.accuracy),
                delta: formatPercentDelta(behavior.metrics.accuracyDelta)
            )
            BehaviorMetric(
                title: "活跃天数",
                value: "\(behavior.metrics.activeDays)/\(behavior.windowDays)",
                delta: formatDeltaInt(behavior.metrics.activeDaysDelta)
            )
        }
    }

    private var drivers: some View {
        VStack(alignment: .leading, spacing: AppMetrics.headerSpacing / 2) {
            ForEach(behavior.drivers.prefix(2), id: \.self) { driver in
                Text(driver)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private func stateColor(_ label: String) -> Color {
        switch label {
        case "On Track":
            return AppTheme.statusSuccess
        case "At Risk":
            return AppTheme.statusDanger
        case "Catching Up":
            return AppTheme.accentStrong
        case "Inconsistent":
            return AppTheme.statusWarning
        default:
            return AppTheme.textMuted
        }
    }

    private func formatPercent(_ value: Double?) -> String {
        guard let value else { return "N/A" }
        return String(format: "%.0f%%", value * 100)
    }

    private func formatPercentDelta(_ value: Double?) -> String? {
        guard let value else { return nil }
        let sign = value >= 0 ? "+" : ""
        return sign + String(format: "%.0f%%", value * 100)
    }

    private func formatDelta(value: Double, suffix: String) -> String {
        let sign = value >= 0 ? "+" : ""
        return sign + String(format: "%.1f", value) + suffix
    }

    private func formatDeltaInt(_ value: Int) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(value)"
    }
}

private struct BehaviorMetric: View {
    let title: String
    let value: String
    let delta: String?

    var body: some View {
        VStack(alignment: .leading, spacing: AppMetrics.headerSpacing / 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textMuted)
            Text(value)
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            if let delta {
                Text(delta)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appSurface(fill: AppTheme.surface, stroke: AppTheme.divider)
        .padding(AppMetrics.headerSpacing)
    }
}

private struct StudyBehaviorStrip: View {
    let daily: [StudyBehavior.DailyPoint]

    var body: some View {
        let maxMinutes = daily.map(\.minutes).max() ?? 0

        let barWidth = AppMetrics.selectionIndicatorWidth * 2.5

        HStack(spacing: AppMetrics.headerSpacing) {
            ForEach(daily) { point in
                VStack(spacing: AppMetrics.headerSpacing / 2) {
                    RoundedRectangle(cornerRadius: AppMetrics.selectionIndicatorCornerRadius, style: .continuous)
                        .fill(AppTheme.accentSoft)
                        .frame(width: barWidth, height: barHeight(minutes: point.minutes, maxMinutes: maxMinutes))

                    Text(label(for: point.date))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func barHeight(minutes: Double, maxMinutes: Double) -> CGFloat {
        let minHeight = AppMetrics.badgeSizeMini / 3
        let maxExtra = AppMetrics.badgeSizeMini * 0.75
        if maxMinutes <= 0 { return minHeight }
        let scaled = minHeight + (minutes / maxMinutes) * maxExtra
        return max(minHeight, scaled)
    }

    private func label(for dateString: String) -> String {
        if let date = StudyBehaviorCard.dateParser.date(from: dateString) {
            return StudyBehaviorCard.dateLabelFormatter.string(from: date)
        }
        return dateString
    }
}
