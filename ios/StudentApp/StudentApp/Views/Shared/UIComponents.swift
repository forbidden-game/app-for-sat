import SwiftUI

// MARK: - Primary CTA Button

struct PrimaryCTAButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(AppTheme.textOnAccent)
                } else {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.textOnAccent)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(AppTheme.ctaFillGradient)
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.rowCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.rowCornerRadius, style: .continuous)
                    .stroke(AppTheme.ctaStrokeGradient, lineWidth: 1)
            )
            .shadow(
                color: AppTheme.shadowSoft,
                radius: AppMetrics.shadowRadiusButton,
                x: 0,
                y: AppMetrics.shadowYButton
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .animation(.easeInOut(duration: AppMetrics.animationDurationFast), value: isDisabled)
    }
}

// MARK: - Secondary CTA Button

struct SecondaryCTAButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(AppTheme.textPrimary)
                } else {
                    Text(title)
                        .font(AppFont.buttonSecondary)
                        .foregroundStyle(AppTheme.textOnAccent)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppMetrics.primaryButtonPaddingVertical)
            .background(AppTheme.accentStrong)
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.rowCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.rowCornerRadius, style: .continuous)
                    .stroke(AppTheme.accent, lineWidth: AppMetrics.strokeWidthThin)
            )
            .shadow(
                color: AppTheme.shadowStrong,
                radius: AppMetrics.shadowRadiusCard,
                x: 0,
                y: AppMetrics.shadowYCard
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .animation(.easeInOut(duration: AppMetrics.animationDurationFast), value: isLoading)
    }
}

// MARK: - Option Badge

struct OptionBadge: View {
    let label: String
    let isSelected: Bool

    var body: some View {
        Text(label)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? AppTheme.boardLight : AppTheme.textSecondary)
            .frame(
                width: AppMetrics.badgeSize,
                height: AppMetrics.badgeSize
            )
            .background(isSelected ? AppTheme.boardDark : AppTheme.surfaceRaised)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(
                        isSelected ? AppTheme.boardDark : AppTheme.dividerStrong,
                        lineWidth: isSelected ? AppMetrics.strokeWidthThick : AppMetrics.strokeWidthMedium
                    )
            )
    }
}

// MARK: - Index Badge

struct IndexBadge: View {
    let index: Int
    let isCorrect: Bool?

    var body: some View {
        Text("\(index)")
            .font(AppFont.listIndex)
            .foregroundStyle(AppTheme.textMuted)
            .frame(
                width: AppMetrics.badgeSizeSmall,
                height: AppMetrics.badgeSizeSmall
            )
            .background(AppTheme.surfaceRaised)
            .clipShape(Circle())
    }
}

// MARK: - Status Icon

struct StatusIcon: View {
    let isSuccess: Bool
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.system(size: size))
            .foregroundStyle(isSuccess ? AppTheme.statusSuccess : AppTheme.statusDanger)
    }
}

// MARK: - Avatar View

struct AvatarView: View {
    let avatarUrl: String?
    let placeholder: String
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.surfaceRaised)
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(AppTheme.divider, lineWidth: 1)
                )

            if let avatarUrl, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Text(placeholder)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                Text(placeholder)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}

// MARK: - Profile Avatar View

struct ProfileAvatarView: View {
    let initials: String

    var body: some View {
        Text(initials)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.textPrimary)
            .frame(width: 32, height: 32)
            .background(AppTheme.surface)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(AppTheme.divider, lineWidth: 1)
            )
    }
}

// MARK: - Modal Top Bar

struct ModalTopBar: View {
    let title: String
    let showsClose: Bool
    let leadingSystemImage: String
    let onClose: () -> Void
    let trailing: AnyView?

    init(
        title: String,
        showsClose: Bool = true,
        leadingSystemImage: String = "xmark",
        onClose: @escaping () -> Void,
        trailing: AnyView? = nil
    ) {
        self.title = title
        self.showsClose = showsClose
        self.leadingSystemImage = leadingSystemImage
        self.onClose = onClose
        self.trailing = trailing
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if showsClose {
                    Button(action: onClose) {
                        Image(systemName: leadingSystemImage)
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

                Spacer()

                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                if let trailing {
                    trailing
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
}

// MARK: - Practice Top Bar

private struct PracticeTopBarIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.textPrimary.opacity(configuration.isPressed ? 0.14 : 0.0))
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .animation(.easeInOut(duration: AppMetrics.animationDurationFast), value: configuration.isPressed)
    }
}

private struct PracticeTopBarPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .background(
                Capsule()
                    .fill(AppTheme.surfaceRaised.opacity(configuration.isPressed ? 0.92 : 1.0))
            )
            .overlay(
                Capsule().stroke(AppTheme.divider, lineWidth: 1)
            )
            .contentShape(Capsule())
            .animation(.easeInOut(duration: AppMetrics.animationDurationFast), value: configuration.isPressed)
    }
}

private struct PracticeProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(progress, 0), 1)
            let width = proxy.size.width * clamped

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.surfaceRaised)
                    .overlay(
                        Capsule().stroke(AppTheme.divider.opacity(0.6), lineWidth: 1)
                    )

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.accentStrong, AppTheme.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: AppTheme.accentStrong.opacity(0.35), radius: 6, x: 0, y: 2)
                    .frame(width: width)
            }
        }
        .frame(height: 6)
    }
}

struct PracticeTopBar: View {
    let progress: Double
    let index: Int
    let total: Int
    let onBack: () -> Void
    let onOverview: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                    .buttonStyle(PracticeTopBarPillButtonStyle())

                Spacer()

                Spacer()

                HStack(spacing: 4) {
                    Text("\(index)")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("/\(total)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)

                Spacer()

                Button("Overview", action: onOverview)
                    .buttonStyle(PracticeTopBarPillButtonStyle())
            }

            PracticeProgressBar(progress: progress)
                .frame(height: 4)
        }
        .padding(.horizontal, AppMetrics.screenHorizontalPadding)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [Color.black.opacity(0.22), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 12)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Primary CTA Button Preview

#Preview("Primary CTA Button") {
    ZStack {
        AppTheme.backgroundGradient
            .ignoresSafeArea()

        VStack(spacing: 20) {
            PrimaryCTAButton(title: "练习", isLoading: false, isDisabled: false) {
                print("Primary CTA tapped")
            }

            PrimaryCTAButton(title: "加载中...", isLoading: true, isDisabled: false) {
                print("Loading button tapped")
            }

            PrimaryCTAButton(title: "禁用", isLoading: false, isDisabled: true) {
                print("Disabled button tapped")
            }

            SecondaryCTAButton(title: "Done", isLoading: false) {
                print("Secondary CTA tapped")
            }
        }
        .padding(20)
    }
}

// MARK: - Option Badge Preview

#Preview("Option Badge") {
    ZStack {
        AppTheme.backgroundGradient
            .ignoresSafeArea()

        HStack(spacing: 20) {
            OptionBadge(label: "A", isSelected: false)
            OptionBadge(label: "B", isSelected: true)
            OptionBadge(label: "C", isSelected: false)
            OptionBadge(label: "D", isSelected: false)
        }
    }
}
