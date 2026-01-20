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
    // Core palette (Dark-only visual; light uses same values for stability).
    static let chromeBackground = dynamicColor(
        light: uiColor(hex: 0x22211F),
        dark: uiColor(hex: 0x22211F)
    )
    static let chromeDivider = dynamicColor(
        light: uiColor(hex: 0x3A3835),
        dark: uiColor(hex: 0x3A3835)
    )

    static let backgroundPrimary = dynamicColor(
        light: uiColor(hex: 0x312E2B),
        dark: uiColor(hex: 0x312E2B)
    )
    static let backgroundSecondary = dynamicColor(
        light: uiColor(hex: 0x292925),
        dark: uiColor(hex: 0x292925)
    )
    static let backgroundTop = backgroundPrimary
    static let backgroundBottom = backgroundSecondary

    static let surface = dynamicColor(
        light: uiColor(hex: 0x383532),
        dark: uiColor(hex: 0x383532)
    )
    static let surfaceRaised = dynamicColor(
        light: uiColor(hex: 0x3E3B38),
        dark: uiColor(hex: 0x3E3B38)
    )
    static let surfacePressed = dynamicColor(
        light: uiColor(hex: 0x2F2D2A),
        dark: uiColor(hex: 0x2F2D2A)
    )

    static let textPrimary = dynamicColor(
        light: uiColor(hex: 0xFFFFFF),
        dark: uiColor(hex: 0xFFFFFF)
    )
    static let textSecondary = dynamicColor(
        light: uiColor(hex: 0xB7B6B5),
        dark: uiColor(hex: 0xB7B6B5)
    )
    static let textMuted = dynamicColor(
        light: uiColor(hex: 0x666564),
        dark: uiColor(hex: 0x666564)
    )
    static let textOnAccent = dynamicColor(
        light: uiColor(hex: 0xFFFFFF),
        dark: uiColor(hex: 0xFFFFFF)
    )

    static let accent = dynamicColor(
        light: uiColor(hex: 0x85A94E),
        dark: uiColor(hex: 0x85A94E)
    )
    static let accentStrong = dynamicColor(
        light: uiColor(hex: 0x85A94E),
        dark: uiColor(hex: 0x85A94E)
    )
    static let accentSoft = dynamicColor(
        light: uiColor(hex: 0x3C4630),
        dark: uiColor(hex: 0x3C4630)
    )

    static let statusSuccess = dynamicColor(
        light: uiColor(hex: 0x7D945D),
        dark: uiColor(hex: 0x7D945D)
    )
    static let statusWarning = dynamicColor(
        light: uiColor(hex: 0xC89050),
        dark: uiColor(hex: 0xC89050)
    )
    static let statusDanger = dynamicColor(
        light: uiColor(hex: 0xC46A5B),
        dark: uiColor(hex: 0xC46A5B)
    )

    static let divider = dynamicColor(
        light: uiColor(hex: 0x3F3C39),
        dark: uiColor(hex: 0x3F3C39)
    )
    static let dividerStrong = dynamicColor(
        light: uiColor(hex: 0x4A4743),
        dark: uiColor(hex: 0x4A4743)
    )

    static let shadowStrong = dynamicColor(
        light: UIColor(white: 0.0, alpha: 0.45),
        dark: UIColor(white: 0.0, alpha: 0.45)
    )
    static let shadowSoft = dynamicColor(
        light: UIColor(white: 0.0, alpha: 0.25),
        dark: UIColor(white: 0.0, alpha: 0.25)
    )

    // CTA gradient (iOS screenshot accurate).
    static let ctaGreenFillTop = dynamicColor(
        light: uiColor(hex: 0x85A94E),
        dark: uiColor(hex: 0x85A94E)
    )
    static let ctaGreenFillBottom = dynamicColor(
        light: uiColor(hex: 0x5F7E39),
        dark: uiColor(hex: 0x5F7E39)
    )
    static let ctaGreenStrokeTop = dynamicColor(
        light: uiColor(hex: 0x81A44C),
        dark: uiColor(hex: 0x81A44C)
    )
    static let ctaGreenStrokeBottom = dynamicColor(
        light: uiColor(hex: 0x516E32),
        dark: uiColor(hex: 0x516E32)
    )

    // Board tones (for selection accents).
    static let boardLight = dynamicColor(
        light: uiColor(hex: 0xEBECD3),
        dark: uiColor(hex: 0xEBECD3)
    )
    static let boardDark = dynamicColor(
        light: uiColor(hex: 0x7D945D),
        dark: uiColor(hex: 0x7D945D)
    )

    // Coach palette mapped to global tokens for unified look.
    static let coachBackgroundTop = backgroundPrimary
    static let coachBackgroundBottom = backgroundSecondary
    static let coachSurface = surface
    static let coachSurfaceAlt = surfaceRaised
    static let coachSurfacePressed = surfacePressed
    static let coachTextPrimary = textPrimary
    static let coachTextSecondary = textSecondary
    static let coachTextMuted = textMuted
    static let coachTextOnAccent = textOnAccent
    static let coachAccent = accent
    static let coachAccentStrong = accentStrong
    static let coachAccentSoft = accentSoft
    static let coachBorder = divider
    static let coachBorderStrong = dividerStrong
    static let coachShadowStrong = shadowStrong
    static let coachShadowSoft = shadowSoft

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var coachBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [coachBackgroundTop, coachBackgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var ctaFillGradient: LinearGradient {
        LinearGradient(
            colors: [ctaGreenFillTop, ctaGreenFillBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var ctaStrokeGradient: LinearGradient {
        LinearGradient(
            colors: [ctaGreenStrokeTop, ctaGreenStrokeBottom],
            startPoint: .top,
            endPoint: .bottom
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

    private static func uiColor(hex: UInt32, alpha: CGFloat = 1) -> UIColor {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        return UIColor(red: r, green: g, blue: b, alpha: alpha)
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
    static let cardCornerRadius: CGFloat = 16
    static let cardPadding: CGFloat = 18
    static let cardShadowRadius: CGFloat = 4
    static let cardShadowY: CGFloat = 2

    static let rowCornerRadius: CGFloat = 14
    static let rowPaddingVertical: CGFloat = 10
    static let rowPaddingHorizontal: CGFloat = 16
    static let rowShadowRadius: CGFloat = 4
    static let rowShadowY: CGFloat = 2

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

    static let panelCornerRadius: CGFloat = 24
    static let panelShadowRadius: CGFloat = 12
    static let panelShadowY: CGFloat = 6

    static let topBarHeight: CGFloat = 52
    static let tabBarHeight: CGFloat = 64
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
