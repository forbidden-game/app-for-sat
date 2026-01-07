import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum AppTheme {
    static let backgroundTop = dynamicColor(
        light: UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1),
        dark: UIColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 1)
    )
    static let backgroundBottom = dynamicColor(
        light: UIColor(red: 0.93, green: 0.95, blue: 0.98, alpha: 1),
        dark: UIColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 1)
    )
    static let surface = dynamicColor(
        light: UIColor(red: 0.99, green: 0.99, blue: 1.0, alpha: 1),
        dark: UIColor(red: 0.13, green: 0.16, blue: 0.22, alpha: 1)
    )
    static let surfaceRaised = dynamicColor(
        light: UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1),
        dark: UIColor(red: 0.18, green: 0.22, blue: 0.30, alpha: 1)
    )
    static let surfacePressed = dynamicColor(
        light: UIColor(red: 0.92, green: 0.94, blue: 0.97, alpha: 1),
        dark: UIColor(red: 0.22, green: 0.27, blue: 0.36, alpha: 1)
    )
    static let textPrimary = dynamicColor(
        light: UIColor(red: 0.07, green: 0.09, blue: 0.13, alpha: 1),
        dark: UIColor(red: 0.92, green: 0.94, blue: 0.97, alpha: 1)
    )
    static let textSecondary = dynamicColor(
        light: UIColor(red: 0.23, green: 0.26, blue: 0.33, alpha: 1),
        dark: UIColor(red: 0.78, green: 0.82, blue: 0.88, alpha: 1)
    )
    static let textMuted = dynamicColor(
        light: UIColor(red: 0.45, green: 0.50, blue: 0.58, alpha: 1),
        dark: UIColor(red: 0.62, green: 0.68, blue: 0.77, alpha: 1)
    )
    static let accent = dynamicColor(
        light: UIColor(red: 0.26, green: 0.49, blue: 0.86, alpha: 1),
        dark: UIColor(red: 0.52, green: 0.70, blue: 0.98, alpha: 1)
    )
    static let accentStrong = dynamicColor(
        light: UIColor(red: 0.36, green: 0.58, blue: 0.96, alpha: 1),
        dark: UIColor(red: 0.67, green: 0.80, blue: 1.0, alpha: 1)
    )
    static let divider = dynamicColor(
        light: UIColor(red: 0.82, green: 0.84, blue: 0.88, alpha: 1),
        dark: UIColor(white: 1.0, alpha: 0.18)
    )
    static let dividerStrong = dynamicColor(
        light: UIColor(red: 0.76, green: 0.79, blue: 0.85, alpha: 1),
        dark: UIColor(white: 1.0, alpha: 0.32)
    )
    static let shadowStrong = dynamicColor(
        light: UIColor(white: 0.0, alpha: 0.14),
        dark: UIColor(white: 0.0, alpha: 0.45)
    )
    static let shadowSoft = dynamicColor(
        light: UIColor(white: 0.0, alpha: 0.08),
        dark: UIColor(white: 0.0, alpha: 0.30)
    )

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [backgroundTop, backgroundBottom],
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

extension View {
    func appCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppTheme.dividerStrong, lineWidth: 1)
            )
            .shadow(color: AppTheme.shadowStrong, radius: 16, x: 0, y: 8)
    }
}
