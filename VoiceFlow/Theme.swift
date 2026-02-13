import SwiftUI

extension Color {
    // Theme-aware colors — delegate to ThemeManager singleton
    static var bitcoinOrange: Color { ThemeManager.shared.accentColor }
    static var darkBackground: Color { ThemeManager.shared.backgroundColor }
    static var darkSurface: Color { ThemeManager.shared.surfaceColor }
    static var darkSurfaceLight: Color {
        // Slightly lighter variant of surface
        let ui = UIColor(ThemeManager.shared.surfaceColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(red: min(r + 0.05, 1), green: min(g + 0.05, 1), blue: min(b + 0.05, 1))
    }
}
