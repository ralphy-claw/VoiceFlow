import SwiftUI

enum ThemePreset: String, CaseIterable, Identifiable {
    case bitcoinOrange = "Bitcoin Orange"
    case oceanBlue = "Ocean Blue"
    case neonGreen = "Neon Green"
    case roseGold = "Rose Gold"
    case midnightPurple = "Midnight Purple"
    case pureDark = "Pure Dark"
    case custom = "Custom"
    
    var id: String { rawValue }
    
    var colors: (accent: Color, background: Color, surface: Color, text: Color) {
        switch self {
        case .bitcoinOrange:
            return (
                Color(red: 242/255, green: 169/255, blue: 0/255),
                Color(red: 13/255, green: 13/255, blue: 13/255),
                Color(red: 26/255, green: 26/255, blue: 30/255),
                Color.white
            )
        case .oceanBlue:
            return (
                Color(red: 0/255, green: 150/255, blue: 255/255),
                Color(red: 10/255, green: 15/255, blue: 25/255),
                Color(red: 18/255, green: 28/255, blue: 42/255),
                Color.white
            )
        case .neonGreen:
            return (
                Color(red: 0/255, green: 255/255, blue: 136/255),
                Color(red: 10/255, green: 14/255, blue: 10/255),
                Color(red: 20/255, green: 28/255, blue: 22/255),
                Color.white
            )
        case .roseGold:
            return (
                Color(red: 235/255, green: 150/255, blue: 135/255),
                Color(red: 18/255, green: 12/255, blue: 12/255),
                Color(red: 32/255, green: 24/255, blue: 24/255),
                Color.white
            )
        case .midnightPurple:
            return (
                Color(red: 160/255, green: 100/255, blue: 255/255),
                Color(red: 12/255, green: 10/255, blue: 20/255),
                Color(red: 24/255, green: 20/255, blue: 38/255),
                Color.white
            )
        case .pureDark:
            return (
                Color.white,
                Color.black,
                Color(red: 18/255, green: 18/255, blue: 18/255),
                Color.white
            )
        case .custom:
            return (.orange, .black, .gray, .white) // placeholder, custom uses stored values
        }
    }
}

@Observable
final class ThemeManager {
    static let shared = ThemeManager()
    
    var accentColor: Color
    var backgroundColor: Color
    var surfaceColor: Color
    var textColor: Color
    
    var selectedPreset: ThemePreset {
        didSet {
            UserDefaults.standard.set(selectedPreset.rawValue, forKey: "selectedThemePreset")
            if selectedPreset != .custom {
                applyPreset(selectedPreset)
            }
        }
    }
    
    // Surface light is derived from surface
    var surfaceLightColor: Color {
        // Slightly lighter than surface
        surfaceColor.opacity(1) // We'll blend
    }
    
    init() {
        let presetName = UserDefaults.standard.string(forKey: "selectedThemePreset") ?? "Bitcoin Orange"
        let preset = ThemePreset(rawValue: presetName) ?? .bitcoinOrange
        self.selectedPreset = preset
        
        if preset == .custom {
            // Load custom colors from UserDefaults
            self.accentColor = Self.loadColor(key: "customAccent") ?? ThemePreset.bitcoinOrange.colors.accent
            self.backgroundColor = Self.loadColor(key: "customBackground") ?? ThemePreset.bitcoinOrange.colors.background
            self.surfaceColor = Self.loadColor(key: "customSurface") ?? ThemePreset.bitcoinOrange.colors.surface
            self.textColor = Self.loadColor(key: "customText") ?? ThemePreset.bitcoinOrange.colors.text
        } else {
            let colors = preset.colors
            self.accentColor = colors.accent
            self.backgroundColor = colors.background
            self.surfaceColor = colors.surface
            self.textColor = colors.text
        }
    }
    
    func applyPreset(_ preset: ThemePreset) {
        let colors = preset.colors
        accentColor = colors.accent
        backgroundColor = colors.background
        surfaceColor = colors.surface
        textColor = colors.text
    }
    
    func saveCustomColors() {
        Self.saveColor(accentColor, key: "customAccent")
        Self.saveColor(backgroundColor, key: "customBackground")
        Self.saveColor(surfaceColor, key: "customSurface")
        Self.saveColor(textColor, key: "customText")
    }
    
    private static func saveColor(_ color: Color, key: String) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        UserDefaults.standard.set([Double(r), Double(g), Double(b), Double(a)], forKey: key)
    }
    
    private static func loadColor(key: String) -> Color? {
        guard let components = UserDefaults.standard.array(forKey: key) as? [Double],
              components.count == 4 else { return nil }
        return Color(red: components[0], green: components[1], blue: components[2], opacity: components[3])
    }
}
