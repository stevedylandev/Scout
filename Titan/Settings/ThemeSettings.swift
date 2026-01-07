//
//  ThemeSettings.swift
//  Titan
//

import SwiftUI
import Combine

/// Appearance mode options
enum AppearanceMode: String, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .automatic: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var icon: String {
        switch self {
        case .automatic: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

/// Available font design options for the browser
enum FontDesignOption: String, CaseIterable, Identifiable {
    case system = "System"
    case monospaced = "Monospaced"
    case serif = "Serif"
    case rounded = "Rounded"

    var id: String { rawValue }

    var fontDesign: Font.Design {
        switch self {
        case .system: return .default
        case .monospaced: return .monospaced
        case .serif: return .serif
        case .rounded: return .rounded
        }
    }
}

/// Observable object that manages theme customization settings.
/// This provides centralized accent color management that views can subscribe to.
class ThemeSettings: ObservableObject {
    /// The appearance mode (light, dark, or automatic)
    @Published var appearanceMode: AppearanceMode = .automatic

    /// The primary accent color used for interactive elements like links and buttons
    @Published var accentColor: Color = .blue

    /// The color used specifically for the loading progress bar
    @Published var progressBarColor: Color = .blue

    /// The color used for link text in Gemini content
    @Published var linkColor: Color = .blue

    /// The color used for media player controls (play button, slider, etc.)
    @Published var mediaAccentColor: Color = .blue

    /// The color used for toolbar buttons (navigation, menu, etc.)
    @Published var toolbarButtonColor: Color = .blue

    /// The background color for the main content area (light mode)
    @Published var lightBackgroundColor: Color = .white

    /// The text color for content (light mode)
    @Published var lightTextColor: Color = .black

    /// The background color for the main content area (dark mode)
    @Published var darkBackgroundColor: Color = Color(red: 0.1, green: 0.1, blue: 0.1)

    /// The text color for content (dark mode)
    @Published var darkTextColor: Color = .white

    /// The font design for content
    @Published var fontDesign: FontDesignOption = .monospaced

    /// The home page URL that the browser navigates to on launch and when pressing Home
    @AppStorage("homePage") var homePage: String = "gemini://geminiprotocol.net/"

    /// The search engine URL used for search queries (query appended after ?)
    @AppStorage("searchEngine") var searchEngine: String = "gemini://kennedy.gemi.dev/search"

    /// Computed property for current background color based on system appearance
    var backgroundColor: Color {
        switch appearanceMode {
        case .light:
            return lightBackgroundColor
        case .dark:
            return darkBackgroundColor
        case .automatic:
            // Use appropriate custom color based on current system appearance
            let isDark = UITraitCollection.current.userInterfaceStyle == .dark
            return isDark ? darkBackgroundColor : lightBackgroundColor
        }
    }

    /// Computed property for current text color based on system appearance
    var textColor: Color {
        switch appearanceMode {
        case .light:
            return lightTextColor
        case .dark:
            return darkTextColor
        case .automatic:
            // Use appropriate custom color based on current system appearance
            let isDark = UITraitCollection.current.userInterfaceStyle == .dark
            return isDark ? darkTextColor : lightTextColor
        }
    }

    /// Key for persisting values
    private static let accentColorKey = "accentColorHex"
    private static let appearanceModeKey = "appearanceMode"
    private static let lightBackgroundColorKey = "lightBackgroundColorHex"
    private static let lightTextColorKey = "lightTextColorHex"
    private static let darkBackgroundColorKey = "darkBackgroundColorHex"
    private static let darkTextColorKey = "darkTextColorHex"
    private static let fontDesignKey = "fontDesign"

    init() {
        if let modeRaw = UserDefaults.standard.string(forKey: Self.appearanceModeKey),
           let mode = AppearanceMode(rawValue: modeRaw) {
            appearanceMode = mode
        }
        if let hex = UserDefaults.standard.string(forKey: Self.accentColorKey),
           let color = Color(hex: hex) {
            setAllAccentColors(color, persist: false)
        }
        if let hex = UserDefaults.standard.string(forKey: Self.lightBackgroundColorKey),
           let color = Color(hex: hex) {
            lightBackgroundColor = color
        }
        if let hex = UserDefaults.standard.string(forKey: Self.lightTextColorKey),
           let color = Color(hex: hex) {
            lightTextColor = color
        }
        if let hex = UserDefaults.standard.string(forKey: Self.darkBackgroundColorKey),
           let color = Color(hex: hex) {
            darkBackgroundColor = color
        }
        if let hex = UserDefaults.standard.string(forKey: Self.darkTextColorKey),
           let color = Color(hex: hex) {
            darkTextColor = color
        }
        if let fontRaw = UserDefaults.standard.string(forKey: Self.fontDesignKey),
           let font = FontDesignOption(rawValue: fontRaw) {
            fontDesign = font
        }
    }

    /// Sets all accent colors to the given color and optionally persists the choice
    func setAllAccentColors(_ color: Color, persist: Bool = true) {
        accentColor = color
        progressBarColor = color
        linkColor = color
        mediaAccentColor = color
        toolbarButtonColor = color

        if persist, let hex = color.toHex() {
            UserDefaults.standard.set(hex, forKey: Self.accentColorKey)
        }
    }

    /// Sets the appearance mode and persists the choice
    func setAppearanceMode(_ mode: AppearanceMode) {
        appearanceMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Self.appearanceModeKey)
    }

    /// Sets the light mode background color and persists the choice
    func setLightBackgroundColor(_ color: Color) {
        lightBackgroundColor = color
        if let hex = color.toHex() {
            UserDefaults.standard.set(hex, forKey: Self.lightBackgroundColorKey)
        }
    }

    /// Sets the light mode text color and persists the choice
    func setLightTextColor(_ color: Color) {
        lightTextColor = color
        if let hex = color.toHex() {
            UserDefaults.standard.set(hex, forKey: Self.lightTextColorKey)
        }
    }

    /// Sets the dark mode background color and persists the choice
    func setDarkBackgroundColor(_ color: Color) {
        darkBackgroundColor = color
        if let hex = color.toHex() {
            UserDefaults.standard.set(hex, forKey: Self.darkBackgroundColorKey)
        }
    }

    /// Sets the dark mode text color and persists the choice
    func setDarkTextColor(_ color: Color) {
        darkTextColor = color
        if let hex = color.toHex() {
            UserDefaults.standard.set(hex, forKey: Self.darkTextColorKey)
        }
    }

    /// Sets the font design and persists the choice
    func setFontDesign(_ font: FontDesignOption) {
        fontDesign = font
        UserDefaults.standard.set(font.rawValue, forKey: Self.fontDesignKey)
    }
}

// MARK: - Color Hex Conversion

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }

    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components else { return nil }

        let r = components.count > 0 ? components[0] : 0
        let g = components.count > 1 ? components[1] : 0
        let b = components.count > 2 ? components[2] : 0

        return String(format: "#%02X%02X%02X",
                      Int(r * 255),
                      Int(g * 255),
                      Int(b * 255))
    }
}

// MARK: - Environment Key

private struct ThemeSettingsKey: EnvironmentKey {
    static let defaultValue = ThemeSettings()
}

extension EnvironmentValues {
    var themeSettings: ThemeSettings {
        get { self[ThemeSettingsKey.self] }
        set { self[ThemeSettingsKey.self] = newValue }
    }
}
