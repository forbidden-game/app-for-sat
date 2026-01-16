import SwiftUI
#if canImport(UIKit)
import UIKit
import CoreText
#endif

// Semantic color tokens (usage rules):
// - Background: screen-level surfaces and gradients only
// - Surface: cards, panels, and elevated containers
// - Text: primary, secondary, muted hierarchy for legibility
// - Accent: primary actions, highlights, and focus states
// - Status: success, warning, danger feedback states
// - Divider/Shadow: separation and elevation layers

enum AppTheme {
    // Coach Chat warm palette (mid-change: scoped usage)
    static let coachBackgroundTop = dynamicColor(
        light: UIColor(red: 0.99, green: 0.97, blue: 0.96, alpha: 1),
        dark: UIColor(red: 0.07, green: 0.07, blue: 0.10, alpha: 1)
    )
    static let coachBackgroundBottom = dynamicColor(
        light: UIColor(red: 0.93, green: 0.95, blue: 1.0, alpha: 1),
        dark: UIColor(red: 0.11, green: 0.12, blue: 0.18, alpha: 1)
    )
    static let coachSurface = dynamicColor(
        light: UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1),
        dark: UIColor(red: 0.15, green: 0.15, blue: 0.22, alpha: 1)
    )
    static let coachSurfaceAlt = dynamicColor(
        light: UIColor(red: 0.95, green: 0.96, blue: 1.00, alpha: 1),
        dark: UIColor(red: 0.20, green: 0.20, blue: 0.28, alpha: 1)
    )
    static let coachSurfacePressed = dynamicColor(
        light: UIColor(red: 0.92, green: 0.93, blue: 0.98, alpha: 1),
        dark: UIColor(red: 0.24, green: 0.24, blue: 0.32, alpha: 1)
    )
    static let coachTextPrimary = dynamicColor(
        light: UIColor(red: 0.12, green: 0.11, blue: 0.29, alpha: 1),
        dark: UIColor(red: 0.95, green: 0.94, blue: 0.98, alpha: 1)
    )
    static let coachTextSecondary = dynamicColor(
        light: UIColor(red: 0.32, green: 0.30, blue: 0.48, alpha: 1),
        dark: UIColor(red: 0.78, green: 0.80, blue: 0.90, alpha: 1)
    )
    static let coachTextMuted = dynamicColor(
        light: UIColor(red: 0.48, green: 0.46, blue: 0.62, alpha: 1),
        dark: UIColor(red: 0.66, green: 0.68, blue: 0.78, alpha: 1)
    )
    static let coachTextOnAccent = dynamicColor(
        light: UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1),
        dark: UIColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1)
    )
    static let coachAccent = dynamicColor(
        light: UIColor(red: 0.31, green: 0.27, blue: 0.90, alpha: 1),
        dark: UIColor(red: 0.58, green: 0.56, blue: 0.95, alpha: 1)
    )
    static let coachAccentStrong = dynamicColor(
        light: UIColor(red: 0.26, green: 0.23, blue: 0.78, alpha: 1),
        dark: UIColor(red: 0.64, green: 0.62, blue: 0.98, alpha: 1)
    )
    static let coachAccentSoft = dynamicColor(
        light: UIColor(red: 0.90, green: 0.92, blue: 1.00, alpha: 1),
        dark: UIColor(red: 0.20, green: 0.20, blue: 0.30, alpha: 1)
    )
    static let coachBorder = dynamicColor(
        light: UIColor(red: 0.78, green: 0.82, blue: 0.98, alpha: 1),
        dark: UIColor(red: 0.28, green: 0.30, blue: 0.40, alpha: 1)
    )
    static let coachBorderStrong = dynamicColor(
        light: UIColor(red: 0.70, green: 0.74, blue: 0.92, alpha: 1),
        dark: UIColor(red: 0.36, green: 0.38, blue: 0.48, alpha: 1)
    )
    static let coachShadowStrong = dynamicColor(
        light: UIColor(white: 0.0, alpha: 0.14),
        dark: UIColor(white: 0.0, alpha: 0.55)
    )
    static let coachShadowSoft = dynamicColor(
        light: UIColor(white: 0.0, alpha: 0.06),
        dark: UIColor(white: 0.0, alpha: 0.35)
    )
    static let backgroundPrimary = dynamicColor(
        light: UIColor(red: 0.99, green: 0.98, blue: 0.97, alpha: 1),
        dark: UIColor(red: 0.08, green: 0.07, blue: 0.06, alpha: 1)
    )
    static let backgroundSecondary = dynamicColor(
        light: UIColor(red: 0.96, green: 0.95, blue: 0.93, alpha: 1),
        dark: UIColor(red: 0.11, green: 0.10, blue: 0.08, alpha: 1)
    )
    static let backgroundTop = backgroundPrimary
    static let backgroundBottom = backgroundSecondary
    static let surface = dynamicColor(
        light: UIColor(red: 0.996, green: 0.992, blue: 0.987, alpha: 1),
        dark: UIColor(red: 0.12, green: 0.10, blue: 0.09, alpha: 1)
    )
    static let surfaceRaised = dynamicColor(
        light: UIColor(red: 0.97, green: 0.96, blue: 0.94, alpha: 1),
        dark: UIColor(red: 0.15, green: 0.13, blue: 0.11, alpha: 1)
    )
    static let surfacePressed = dynamicColor(
        light: UIColor(red: 0.94, green: 0.92, blue: 0.89, alpha: 1),
        dark: UIColor(red: 0.18, green: 0.16, blue: 0.14, alpha: 1)
    )
    static let textPrimary = dynamicColor(
        light: UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1),
        dark: UIColor(red: 0.95, green: 0.93, blue: 0.90, alpha: 1)
    )
    static let textSecondary = dynamicColor(
        light: UIColor(red: 0.24, green: 0.22, blue: 0.20, alpha: 1),
        dark: UIColor(red: 0.82, green: 0.78, blue: 0.72, alpha: 1)
    )
    static let textMuted = dynamicColor(
        light: UIColor(red: 0.42, green: 0.38, blue: 0.33, alpha: 1),
        dark: UIColor(red: 0.68, green: 0.62, blue: 0.56, alpha: 1)
    )
    static let textOnAccent = dynamicColor(
        light: UIColor(red: 0.99, green: 0.98, blue: 0.97, alpha: 1),
        dark: UIColor(red: 0.99, green: 0.98, blue: 0.97, alpha: 1)
    )
    static let accent = dynamicColor(
        light: UIColor(red: 0.18, green: 0.36, blue: 0.36, alpha: 1),
        dark: UIColor(red: 0.48, green: 0.62, blue: 0.58, alpha: 1)
    )
    static let accentStrong = dynamicColor(
        light: UIColor(red: 0.12, green: 0.28, blue: 0.28, alpha: 1),
        dark: UIColor(red: 0.56, green: 0.72, blue: 0.68, alpha: 1)
    )
    static let accentSoft = dynamicColor(
        light: UIColor(red: 0.90, green: 0.93, blue: 0.91, alpha: 1),
        dark: UIColor(red: 0.18, green: 0.22, blue: 0.20, alpha: 1)
    )
    static let statusSuccess = dynamicColor(
        light: UIColor(red: 0.20, green: 0.47, blue: 0.40, alpha: 1),
        dark: UIColor(red: 0.49, green: 0.70, blue: 0.61, alpha: 1)
    )
    static let statusWarning = dynamicColor(
        light: UIColor(red: 0.70, green: 0.52, blue: 0.20, alpha: 1),
        dark: UIColor(red: 0.82, green: 0.64, blue: 0.34, alpha: 1)
    )
    static let statusDanger = dynamicColor(
        light: UIColor(red: 0.70, green: 0.33, blue: 0.27, alpha: 1),
        dark: UIColor(red: 0.83, green: 0.50, blue: 0.42, alpha: 1)
    )
    static let divider = dynamicColor(
        light: UIColor(red: 0.85, green: 0.82, blue: 0.78, alpha: 1),
        dark: UIColor(red: 0.25, green: 0.22, blue: 0.20, alpha: 1)
    )
    static let dividerStrong = dynamicColor(
        light: UIColor(red: 0.79, green: 0.75, blue: 0.70, alpha: 1),
        dark: UIColor(red: 0.32, green: 0.28, blue: 0.25, alpha: 1)
    )
    static let shadowStrong = dynamicColor(
        light: UIColor(white: 0.0, alpha: 0.10),
        dark: UIColor(white: 0.0, alpha: 0.55)
    )
    static let shadowSoft = dynamicColor(
        light: UIColor(white: 0.0, alpha: 0.04),
        dark: UIColor(white: 0.0, alpha: 0.35)
    )

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var coachBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [coachBackgroundTop, coachBackgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        #if canImport(UIKit)
        return Color(
            UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? dark : light
            }
        )
        #else
        return Color.black
        #endif
    }
}

enum AppFont {
    private static var didRegisterCoachFont = false

    static func registerCoachFontIfNeeded() {
        #if canImport(UIKit)
        guard !didRegisterCoachFont else { return }
        defer { didRegisterCoachFont = true }
        guard !UIFont.familyNames.contains("Noto Sans SC") else { return }
        guard let url = Bundle.main.url(forResource: "NotoSansSC", withExtension: "ttf", subdirectory: "Fonts") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        #endif
    }

    static func coach(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let uiFont = notoFont(size: size, weight: weight) {
            return Font(uiFont)
        }
        if let uiFont = pingFangFont(size: size, weight: weight) {
            return Font(uiFont)
        }
        return .system(size: size, weight: weight, design: .rounded)
    }

    private static func notoFont(size: CGFloat, weight: Font.Weight) -> UIFont? {
        let family = "Noto Sans SC"
        guard UIFont.familyNames.contains(family) else { return nil }
        let descriptor = UIFontDescriptor(fontAttributes: [UIFontDescriptor.AttributeName.family: family])
        let traits = [UIFontDescriptor.TraitKey.weight: uiFontWeight(for: weight)]
        let styled = descriptor.addingAttributes([UIFontDescriptor.AttributeName.traits: traits])
        return UIFont(descriptor: styled, size: size)
    }

    private static func pingFangFont(size: CGFloat, weight: Font.Weight) -> UIFont? {
        let name: String
        switch weight {
        case .semibold:
            name = "PingFangSC-Semibold"
        case .medium:
            name = "PingFangSC-Medium"
        case .bold:
            name = "PingFangSC-Bold"
        default:
            name = "PingFangSC-Regular"
        }
        return UIFont(name: name, size: size)
    }

    private static func uiFontWeight(for weight: Font.Weight) -> UIFont.Weight {
        switch weight {
        case .ultraLight:
            return .ultraLight
        case .thin:
            return .thin
        case .light:
            return .light
        case .medium:
            return .medium
        case .semibold:
            return .semibold
        case .bold:
            return .bold
        case .heavy:
            return .heavy
        case .black:
            return .black
        default:
            return .regular
        }
    }
}

enum AppMetrics {
    static let cardCornerRadius: CGFloat = 20
    static let cardPadding: CGFloat = 18
    static let cardShadowRadius: CGFloat = 8
    static let cardShadowY: CGFloat = 3

    static let rowCornerRadius: CGFloat = 16
    static let rowPaddingVertical: CGFloat = 10
    static let rowPaddingHorizontal: CGFloat = 16
    static let rowShadowRadius: CGFloat = 6
    static let rowShadowY: CGFloat = 3

    static let badgeSize: CGFloat = 32
    static let badgeSizeSmall: CGFloat = 28
    static let gridButtonSize: CGFloat = 48

    static let fieldPaddingVertical: CGFloat = 12
    static let fieldPaddingHorizontal: CGFloat = 16
    static let primaryButtonPaddingVertical: CGFloat = 14

    static let headerSpacing: CGFloat = 8
    static let sectionSpacing: CGFloat = 16
    static let sectionSpacingLarge: CGFloat = 24
    static let rowSpacing: CGFloat = 10
    static let pageBottomPadding: CGFloat = 20

    static let screenHorizontalPadding: CGFloat = 20
    static let screenTopPadding: CGFloat = 16
    static let screenBottomPadding: CGFloat = 24
    static let screenBottomPaddingLarge: CGFloat = 32

    static let gridSpacing: CGFloat = 12
    static let gridSpacingWide: CGFloat = 20
    static let gridItemMinimum: CGFloat = 56

    static let panelCornerRadius: CGFloat = 28
    static let panelShadowRadius: CGFloat = 18
    static let panelShadowY: CGFloat = 10
}

extension View {
    func appCard(padding: CGFloat = AppMetrics.cardPadding) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: AppMetrics.cardCornerRadius, style: .continuous)
                    .fill(AppTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.cardCornerRadius, style: .continuous)
                    .stroke(AppTheme.divider, lineWidth: 1)
            )
            .shadow(color: AppTheme.shadowSoft, radius: AppMetrics.cardShadowRadius, x: 0, y: AppMetrics.cardShadowY)
    }

    func appSurface(
        fill: Color,
        stroke: Color,
        cornerRadius: CGFloat = AppMetrics.rowCornerRadius,
        shadow: Color = AppTheme.shadowSoft,
        shadowRadius: CGFloat = AppMetrics.rowShadowRadius,
        shadowY: CGFloat = AppMetrics.rowShadowY,
        showShadow: Bool = true
    ) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
            .shadow(
                color: showShadow ? shadow : Color.clear,
                radius: showShadow ? shadowRadius : 0,
                x: 0,
                y: showShadow ? shadowY : 0
            )
    }
}
