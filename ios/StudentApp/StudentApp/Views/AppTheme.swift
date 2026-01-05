import SwiftUI

enum AppTheme {
    static let backgroundTop = Color(red: 0.05, green: 0.05, blue: 0.06)
    static let backgroundBottom = Color(red: 0.08, green: 0.08, blue: 0.1)
    static let surface = Color(red: 0.12, green: 0.12, blue: 0.14)
    static let surfaceRaised = Color(red: 0.16, green: 0.16, blue: 0.18)
    static let surfacePressed = Color(red: 0.2, green: 0.2, blue: 0.22)
    static let textPrimary = Color(red: 0.93, green: 0.93, blue: 0.95)
    static let textSecondary = Color(red: 0.6, green: 0.6, blue: 0.65)
    static let textMuted = Color(red: 0.42, green: 0.42, blue: 0.46)
    static let accent = Color(red: 0.78, green: 0.78, blue: 0.83)
    static let accentStrong = Color(red: 0.92, green: 0.92, blue: 0.96)
    static let divider = Color.white.opacity(0.08)

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
                    .stroke(AppTheme.divider, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 8)
    }
}
