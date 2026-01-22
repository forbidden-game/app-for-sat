import SwiftUI

enum MainTab: String, CaseIterable, Identifiable {
    case home
    case coach
    case review

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return "首页"
        case .coach:
            return "王校长"
        case .review:
            return "复盘"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            return "house.fill"
        case .coach:
            return "bubble.left.and.bubble.right.fill"
        case .review:
            return "chart.bar.fill"
        }
    }

    var subtitle: String? {
        switch self {
        case .coach:
            return "AI辅导老师"
        default:
            return nil
        }
    }
}

struct AppTopBar: View {
    let title: String
    let subtitle: String?
    let displayName: String
    let onProfile: () -> Void
    let onSocial: () -> Void
    let showsSocial: Bool

    init(
        title: String,
        subtitle: String? = nil,
        displayName: String,
        onProfile: @escaping () -> Void,
        onSocial: @escaping () -> Void,
        showsSocial: Bool = true
    ) {
        self.title = title
        self.subtitle = subtitle
        self.displayName = displayName
        self.onProfile = onProfile
        self.onSocial = onSocial
        self.showsSocial = showsSocial
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onProfile) {
                    ProfileAvatarView(initials: initials)
                }
                .buttonStyle(.plain)

                VStack(spacing: 2) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)

                if showsSocial {
                    Button(action: onSocial) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(AppTheme.divider, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear
                        .frame(width: 32, height: 32)
                }
            }
            .frame(height: AppMetrics.topBarHeight)
            .padding(.horizontal, AppMetrics.screenHorizontalPadding)
            .background(AppTheme.chromeBackground)
            .safeAreaPadding(.top, 6)

            Rectangle()
                .fill(AppTheme.chromeDivider)
                .frame(height: 1)
        }
    }

    private var initials: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }
        let text = letters.map { String($0) }.joined()
        return text.isEmpty ? "S" : text.uppercased()
    }
}

struct AppTabBar: View {
    @Binding var selected: MainTab

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppTheme.chromeDivider)
                .frame(height: 1)

            HStack {
                ForEach(MainTab.allCases) { tab in
                    Button {
                        selected = tab
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: 18, weight: .semibold))
                            Text(tab.title)
                                .font(.caption)
                        }
                        .foregroundStyle(selected == tab ? AppTheme.accentStrong : AppTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: AppMetrics.tabBarHeight)
            .background(AppTheme.chromeBackground)
            .safeAreaPadding(.bottom, 6)
        }
    }
}

