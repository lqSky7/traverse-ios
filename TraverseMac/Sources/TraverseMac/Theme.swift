import SwiftUI

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct ColorPalette: Identifiable, Codable, Equatable, Hashable {
    let id: Int
    let name: String
    let colors: [String]

    var swiftUIColors: [Color] { colors.map { Color(hex: $0) } }
    var primary: Color { Color(hex: colors.first ?? "8E8E93").adjustedForDarkMode() }
    var secondary: Color { Color(hex: colors.dropFirst().first ?? colors.first ?? "636366").adjustedForDarkMode() }
    var chartColors: [Color] { swiftUIColors.map { $0.adjustedForDarkMode() } }

    static let allPalettes: [ColorPalette] = [
        ColorPalette(id: 0, name: "Monochrome", colors: ["8E8E93", "636366", "AEAEB2", "C7C7CC", "D1D1D6"]),
        ColorPalette(id: 1, name: "Ocean Breeze", colors: ["0077B6", "00B4D8", "90E0EF", "CAF0F8", "48CAE4"]),
        ColorPalette(id: 2, name: "Sunset Glow", colors: ["FF6B6B", "FFA06D", "FFD93D", "FF8E53", "FF5E5B"]),
        ColorPalette(id: 3, name: "Forest Zen", colors: ["2D6A4F", "40916C", "52B788", "74C69D", "95D5B2"]),
        ColorPalette(id: 4, name: "Candy Dream", colors: ["CDB4DB", "FFC8DD", "FFAFCC", "BDE0FE", "A2D2FF"]),
        ColorPalette(id: 5, name: "Neon Nights", colors: ["FF00FF", "00FFFF", "FF6EC7", "7DF9FF", "39FF14"]),
        ColorPalette(id: 6, name: "Lavender Fields", colors: ["E0BBE4", "957DAD", "D291BC", "FEC8D8", "FFDFD3"])
    ]
}

@MainActor
final class ColorPaletteManager: ObservableObject {
    static let shared = ColorPaletteManager()

    @Published var selectedPalette: ColorPalette {
        didSet { savePalette() }
    }

    @Published var customPalette: ColorPalette? {
        didSet { saveCustomPalette() }
    }

    @Published var isDarkMode: Bool {
        didSet { UserDefaults.standard.set(isDarkMode, forKey: Self.darkModeKey) }
    }

    var allAvailablePalettes: [ColorPalette] {
        var palettes = ColorPalette.allPalettes
        if let customPalette { palettes.append(customPalette) }
        return palettes
    }

    private static let selectedPaletteKey = "selectedColorPaletteID"
    private static let customPaletteKey = "customColorPalette"
    private static let darkModeKey = "isDarkMode"

    private init() {
        let loadedCustom = Self.loadCustomPalette()
        let savedID = UserDefaults.standard.value(forKey: Self.selectedPaletteKey) as? Int
        customPalette = loadedCustom
        selectedPalette = loadedCustom.flatMap { $0.id == savedID ? $0 : nil }
            ?? ColorPalette.allPalettes.first { $0.id == savedID }
            ?? ColorPalette.allPalettes[0]
        isDarkMode = UserDefaults.standard.object(forKey: Self.darkModeKey) as? Bool ?? true
    }

    func selectPalette(_ palette: ColorPalette) {
        selectedPalette = palette
    }

    func color(at index: Int) -> Color {
        let colors = selectedPalette.swiftUIColors
        return colors[index % max(colors.count, 1)]
    }

    func streakGradientColors(for streak: Int) -> [Color] {
        let colors = selectedPalette.swiftUIColors
        guard !colors.isEmpty else { return [.gray, .secondary] }
        if streak == 0 {
            return [colors[0].opacity(0.7), (colors[safe: 1] ?? colors[0]).opacity(0.5)]
        }
        if streak >= 100 { return Array(colors.prefix(4)) }
        if streak >= 60 { return Array(colors.suffix(3)) }
        if streak >= 25 { return Array(colors.dropFirst().prefix(3)) }
        return Array(colors.prefix(3))
    }

    func importPalette(from input: String) -> Bool {
        guard let colors = parsePaletteInput(input) else { return false }
        let palette = ColorPalette(id: 999, name: "Custom", colors: colors)
        customPalette = palette
        selectedPalette = palette
        return true
    }

    func createPalette(from base: Color) {
        #if canImport(AppKit)
        let nsColor = NSColor(base).usingColorSpace(.deviceRGB) ?? .systemBlue
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        nsColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        let colors: [NSColor] = [
            nsColor,
            NSColor(hue: wrap(hue + 0.083), saturation: saturation * 0.9, brightness: min(brightness * 1.1, 1), alpha: alpha),
            NSColor(hue: wrap(hue + 0.917), saturation: saturation * 0.9, brightness: min(brightness * 1.1, 1), alpha: alpha),
            NSColor(hue: wrap(hue + 0.5), saturation: saturation * 0.5, brightness: min(brightness * 1.15, 1), alpha: alpha),
            NSColor(hue: wrap(hue + 0.333), saturation: saturation * 0.6, brightness: brightness, alpha: alpha)
        ]
        let palette = ColorPalette(id: 999, name: "Custom", colors: colors.map(\.hexString))
        #elseif canImport(UIKit)
        let uiColor = UIColor(base)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        let colors: [UIColor] = [
            uiColor,
            UIColor(hue: wrap(hue + 0.083), saturation: saturation * 0.9, brightness: min(brightness * 1.1, 1), alpha: alpha),
            UIColor(hue: wrap(hue + 0.917), saturation: saturation * 0.9, brightness: min(brightness * 1.1, 1), alpha: alpha),
            UIColor(hue: wrap(hue + 0.5), saturation: saturation * 0.5, brightness: min(brightness * 1.15, 1), alpha: alpha),
            UIColor(hue: wrap(hue + 0.333), saturation: saturation * 0.6, brightness: brightness, alpha: alpha)
        ]
        let palette = ColorPalette(id: 999, name: "Custom", colors: colors.map(\.hexString))
        #else
        let palette = ColorPalette(id: 999, name: "Custom", colors: ["0077B6", "00B4D8", "90E0EF", "CAF0F8", "48CAE4"])
        #endif
        customPalette = palette
        selectedPalette = palette
    }

    private func wrap(_ value: CGFloat) -> CGFloat {
        let wrapped = value.truncatingRemainder(dividingBy: 1)
        return wrapped < 0 ? wrapped + 1 : wrapped
    }

    private func savePalette() {
        UserDefaults.standard.set(selectedPalette.id, forKey: Self.selectedPaletteKey)
    }

    private func saveCustomPalette() {
        if let customPalette, let data = try? JSONEncoder().encode(customPalette) {
            UserDefaults.standard.set(data, forKey: Self.customPaletteKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.customPaletteKey)
        }
    }

    private static func loadCustomPalette() -> ColorPalette? {
        guard let data = UserDefaults.standard.data(forKey: Self.customPaletteKey) else { return nil }
        return try? JSONDecoder().decode(ColorPalette.self, from: data)
    }

    private func parsePaletteInput(_ input: String) -> [String]? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("coolors.co") { return parseCoolorsURL(trimmed) }
        if trimmed.contains("$"), trimmed.contains(":") { return parseSCSS(trimmed) }

        let direct = trimmed
            .replacingOccurrences(of: "#", with: "")
            .split { $0 == "," || $0 == " " || $0 == "\n" || $0 == "\t" }
            .map(String.init)
            .filter { $0.count == 6 || $0.count == 8 }
        return direct.count >= 3 ? direct : nil
    }

    private func parseCoolorsURL(_ url: String) -> [String]? {
        guard let last = url.components(separatedBy: "/").last else { return nil }
        let colors = last.components(separatedBy: "-")
            .map { $0.replacingOccurrences(of: "#", with: "") }
            .filter { $0.count == 6 || $0.count == 8 }
        return colors.count >= 3 ? colors : nil
    }

    private func parseSCSS(_ scss: String) -> [String]? {
        let colors = scss.components(separatedBy: .newlines).compactMap { line -> String? in
            guard line.contains(":"), line.contains("#") else { return nil }
            let color = line.components(separatedBy: ":").dropFirst().joined(separator: ":")
                .replacingOccurrences(of: "#", with: "")
                .replacingOccurrences(of: ";", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return color.count == 6 || color.count == 8 ? color : nil
        }
        return colors.count >= 3 ? colors : nil
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 142, 142, 147)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }

    var luminance: Double {
        #if canImport(AppKit)
        let color = NSColor(self).usingColorSpace(.deviceRGB) ?? .systemGray
        return 0.2126 * color.redComponent + 0.7152 * color.greenComponent + 0.0722 * color.blueComponent
        #elseif canImport(UIKit)
        let color = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return 0.2126 * Double(red) + 0.7152 * Double(green) + 0.0722 * Double(blue)
        #else
        return 0.5
        #endif
    }

    var isDark: Bool { luminance < 0.3 }

    func adjustedForDarkMode() -> Color {
        let isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        guard isDarkMode, isDark else { return self }
        let alternatives = [Color(hex: "FFC8DD"), Color(hex: "E0BBE4"), Color(hex: "A2D2FF"), Color(hex: "BDE0FE"), Color(hex: "FFDAB9")]
        return alternatives[Int(luminance * Double(alternatives.count)) % alternatives.count]
    }
}

#if canImport(AppKit)
extension NSColor {
    var hexString: String {
        let color = usingColorSpace(.deviceRGB) ?? self
        return String(
            format: "%02X%02X%02X",
            Int(color.redComponent * 255),
            Int(color.greenComponent * 255),
            Int(color.blueComponent * 255)
        )
    }
}
#elseif canImport(UIKit)
extension UIColor {
    var hexString: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
    }
}
#endif

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct ThemedCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.08))
            }
    }
}

struct PanelFeedback: View {
    let status: PanelLoadStatus
    let isEmpty: Bool
    let emptyTitle: String
    let emptySystemImage: String
    let emptyDescription: String

    var body: some View {
        switch status {
        case .loading:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Loading")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
        case .failed(let message):
            ContentUnavailableView(
                "Could not load",
                systemImage: "wifi.exclamationmark",
                description: Text(message)
            )
            .frame(minHeight: 120)
        case .idle, .loaded:
            if isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: emptySystemImage,
                    description: Text(emptyDescription)
                )
                .frame(minHeight: 120)
            }
        }
    }
}

struct PaletteStrip: View {
    let palette: ColorPalette

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(palette.swiftUIColors.enumerated()), id: \.offset) { _, color in
                color
            }
        }
        .frame(width: 76, height: 10)
        .clipShape(Capsule())
    }
}
