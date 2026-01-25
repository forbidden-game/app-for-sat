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
        VStack(alignment: .leading, spacing: 12) {
            header
            metrics
            StudyBehaviorStrip(daily: Array(behavior.daily.suffix(7)))
            drivers
        }
        .padding(16)
        .appSurface(
            fill: AppTheme.surfaceRaised,
            stroke: AppTheme.dividerStrong,
            cornerRadius: 18,
            shadowRadius: 10,
            shadowY: 6
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
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .background(stateColor(behavior.state.label))
                .clipShape(Capsule())
        }
    }

    private var metrics: some View {
        HStack(spacing: 12) {
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
        VStack(alignment: .leading, spacing: 4) {
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
        VStack(alignment: .leading, spacing: 4) {
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
        .padding(8)
    }
}

private struct StudyBehaviorStrip: View {
    let daily: [StudyBehavior.DailyPoint]

    var body: some View {
        let maxMinutes = daily.map(\.minutes).max() ?? 0

        HStack(spacing: 6) {
            ForEach(daily) { point in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(AppTheme.accentSoft)
                        .frame(width: 10, height: barHeight(minutes: point.minutes, maxMinutes: maxMinutes))

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
        if maxMinutes <= 0 { return 8 }
        let scaled = 8 + (minutes / maxMinutes) * 18
        return CGFloat(max(8, scaled))
    }

    private func label(for dateString: String) -> String {
        if let date = StudyBehaviorCard.dateParser.date(from: dateString) {
            return StudyBehaviorCard.dateLabelFormatter.string(from: date)
        }
        return dateString
    }
}
