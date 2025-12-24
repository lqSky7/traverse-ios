import SwiftUI
import Combine

// MARK: - Color Palette Model
struct ColorPalette: Identifiable, Codable, Equatable, Hashable {
    let id: Int
    let name: String
    let colors: [String]
    
    static func == (lhs: ColorPalette, rhs: ColorPalette) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    var swiftUIColors: [Color] {
        colors.map { Color(hex: $0) }
    }
    
    // Primary color for tab icons and main accents
    var primary: Color {
        Color(hex: colors[0]).adjustedForDarkMode()
    }
    
    // Secondary colors for charts
    var chartColors: [Color] {
        swiftUIColors.map { $0.adjustedForDarkMode() }
    }
    
    var secondary: Color {
        Color(hex: colors[safe: 1] ?? colors[0]).adjustedForDarkMode()
    }
    
    static let allPalettes: [ColorPalette] = [
        ColorPalette(
            id: 1,
            name: "Apple Fitness",
            colors: ["FA114F", "92E82A", "00C7BE", "FCD12A", "B7B3FF"]
        ),
        ColorPalette(
            id: 2,
            name: "Ocean Breeze",
            colors: ["E63946", "F1FAEE", "A8DADC", "457B9D", "1D3557"]
        ),
        ColorPalette(
            id: 4,
            name: "Candy Dream",
            colors: ["CDB4DB", "FFC8DD", "FFAFCC", "BDE0FE", "A2D2FF"]
        )
    ]
}

// MARK: - Color Palette Manager
class ColorPaletteManager: ObservableObject {
    static let shared = ColorPaletteManager()
    
    @Published var selectedPalette: ColorPalette {
        didSet {
            savePalette()
        }
    }
    
    @Published var customPalette: ColorPalette? {
        didSet {
            saveCustomPalette()
        }
    }
    
    var allAvailablePalettes: [ColorPalette] {
        var palettes = ColorPalette.allPalettes
        if let custom = customPalette {
            palettes.append(custom)
        }
        return palettes
    }
    
    private static let userDefaultsKey = "selectedColorPaletteID"
    private static let customPaletteKey = "customColorPalette"
    
    private init() {
        // Compute custom palette if it exists
        let loadedCustom: ColorPalette? = {
            if let data = UserDefaults.standard.data(forKey: ColorPaletteManager.customPaletteKey),
               let custom = try? JSONDecoder().decode(ColorPalette.self, from: data) {
                return custom
            } else {
                return nil
            }
        }()

        // Compute selected palette or use default without accessing self before init
        let selected: ColorPalette = {
            if let savedID = UserDefaults.standard.value(forKey: ColorPaletteManager.userDefaultsKey) as? Int {
                if let custom = loadedCustom, custom.id == savedID {
                    return custom
                } else if let palette = ColorPalette.allPalettes.first(where: { $0.id == savedID }) {
                    return palette
                } else {
                    return ColorPalette.allPalettes[0]
                }
            } else {
                return ColorPalette.allPalettes[0]
            }
        }()

        // Now assign to stored properties
        self.customPalette = loadedCustom
        self.selectedPalette = selected
    }
    
    private func savePalette() {
        UserDefaults.standard.set(selectedPalette.id, forKey: ColorPaletteManager.userDefaultsKey)
    }
    
    private func saveCustomPalette() {
        if let custom = customPalette,
           let data = try? JSONEncoder().encode(custom) {
            UserDefaults.standard.set(data, forKey: ColorPaletteManager.customPaletteKey)
        } else {
            UserDefaults.standard.removeObject(forKey: ColorPaletteManager.customPaletteKey)
        }
    }
    
    func selectPalette(_ palette: ColorPalette) {
        selectedPalette = palette
    }
    
    func importPalette(from input: String) -> Bool {
        if let colors = parsePaletteInput(input) {
            let newPalette = ColorPalette(
                id: 999, // Custom palette ID
                name: "Custom",
                colors: colors
            )
            customPalette = newPalette
            selectedPalette = newPalette
            return true
        }
        return false
    }
    
    private func parsePaletteInput(_ input: String) -> [String]? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if it's a coolors.co URL
        if trimmed.contains("coolors.co") {
            return parseCoolorsURL(trimmed)
        }
        
        // Check if it's SCSS format
        if trimmed.contains("$") && trimmed.contains(":") {
            return parseSCSSFormat(trimmed)
        }
        
        return nil
    }
    
    private func parseCoolorsURL(_ url: String) -> [String]? {
        // Extract color codes from coolors.co URL
        // Format: https://coolors.co/palette/ff6ad5-c774e8-ad8cff-8795e8-94d0ff
        // or: https://coolors.co/ff6ad5-c774e8-ad8cff-8795e8-94d0ff
        
        let components = url.components(separatedBy: "/")
        guard let lastComponent = components.last else { return nil }
        
        let colorCodes = lastComponent.components(separatedBy: "-")
        let validColors = colorCodes.compactMap { code -> String? in
            let cleaned = code.replacingOccurrences(of: "#", with: "")
            // Check if it's a valid hex color (6 or 8 characters)
            if cleaned.count == 6 || cleaned.count == 8 {
                return cleaned
            }
            return nil
        }
        
        return validColors.count >= 3 ? validColors : nil
    }
    
    private func parseSCSSFormat(_ scss: String) -> [String]? {
        // Parse SCSS format: $name: #colorff;
        let lines = scss.components(separatedBy: .newlines)
        var colors: [String] = []
        
        for line in lines {
            if line.contains(":") && line.contains("#") {
                let parts = line.components(separatedBy: ":")
                if parts.count >= 2 {
                    let colorPart = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    let colorCode = colorPart.replacingOccurrences(of: "#", with: "")
                                            .replacingOccurrences(of: ";", with: "")
                                            .replacingOccurrences(of: "ff", with: "", options: .anchored, range: nil)
                    
                    let cleaned = colorCode.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleaned.count == 6 || cleaned.count == 8 {
                        colors.append(cleaned)
                    }
                }
            }
        }
        
        return colors.count >= 3 ? colors : nil
    }
    
    // Get color at index with cycling
    func color(at index: Int) -> Color {
        let colors = selectedPalette.swiftUIColors
        return colors[index % colors.count]
    }
    
    // Get gradient colors for streak
    func streakGradientColors(for streak: Int) -> [Color] {
        if streak == 0 {
            return [Color.gray.opacity(0.6), Color.gray.opacity(0.4)]
        }
        
        let colors = selectedPalette.swiftUIColors
        if streak >= 100 {
            return Array(colors.prefix(3))
        } else if streak >= 60 {
            return Array(colors.suffix(3))
        } else if streak >= 25 {
            return Array(colors.dropFirst(2).prefix(3))
        } else {
            return [colors.first ?? .gray, colors[safe: 1] ?? .gray]
        }
    }
}

// MARK: - Array Safe Subscript Extension
extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    // Calculate relative luminance (perceived brightness)
    var luminance: Double {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return 0.5
        }
        let r = components[0]
        let g = components[1]
        let b = components[2]
        
        // Standard relative luminance formula
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
    
    var isDark: Bool {
        luminance < 0.3
    }
    
    func adjustedForDarkMode() -> Color {
        let isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        
        guard isDarkMode, isDark else {
            return self
        }
        
        // Replace dark colors with sensible light alternatives
        // Use pastel shades: light pink, lavender, mint
        let lightAlternatives: [Color] = [
            Color(hex: "FFC8DD"), // Light pink
            Color(hex: "E0BBE4"), // Lavender
            Color(hex: "A2D2FF"), // Light blue
            Color(hex: "BDE0FE"), // Pastel blue
            Color(hex: "FFDAB9")  // Peach
        ]
        
        // Use luminance to determine which alternative to pick
        let index = Int(luminance * Double(lightAlternatives.count))
        return lightAlternatives[index % lightAlternatives.count]
    }
}

