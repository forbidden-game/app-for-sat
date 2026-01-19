import SwiftUI
import UIKit

enum ColorHexBuilder {
    static func hex(for color: Color, scheme: ColorScheme) -> String {
        let uiColor = UIColor(color)
        let traits = UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light)
        let resolved = uiColor.resolvedColor(with: traits)
        return resolved.hexString
    }
}

private extension UIColor {
    var hexString: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return "#1A1A1A"
        }
        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
    }
}
