// This component is heavily inspired by https://github.com/AdelaideSky's work! Please check it out https://apple.co/44pPYhH

import SwiftUI

// MARK: - Dot View
struct DotView: View {
    let center: CGPoint
    let dragLocation: CGPoint?
    let influenceRadius: CGFloat
    let gridSize: CGSize
    let dotSize: CGFloat
    let isGuideDot: Bool
    let vibrancy: Double
    
    private var distance: CGFloat {
        guard let location = dragLocation else { return .infinity }
        let dx = center.x - location.x
        let dy = center.y - location.y
        return sqrt(dx * dx + dy * dy)
    }
    
    private var scale: CGFloat {
        guard dragLocation != nil else { return isGuideDot ? 0.5 : 0.3 }
        let normalized = distance / influenceRadius
        return max(isGuideDot ? 0.5 : 0.3, min(1.5, 1.5 - normalized * 0.8))
    }
    
    private var opacity: CGFloat {
        guard dragLocation != nil else { return isGuideDot ? 0.5 : 0.3 }
        let normalized = distance / influenceRadius
        return max(isGuideDot ? 0.5 : 0.3, min(1.0, 1.0 - normalized * 0.7))
    }
    
    private var dotColor: Color {
        guard dragLocation != nil else { return .gray }
        
        let normalizedX = center.x / gridSize.width
        let normalizedY = center.y / gridSize.height
        
        let hue = normalizedX
        let minSat = 0.10 + (vibrancy * 0.35)
        let maxSat = 0.30 + (vibrancy * 0.65)
        let saturation = minSat + (normalizedY * (maxSat - minSat))
        let brightness: CGFloat = 0.98 - (vibrancy * 0.08)
        
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
    
    var body: some View {
        Circle()
            .fill(dotColor)
            .frame(width: isGuideDot ? dotSize * 1.2 : dotSize, height: isGuideDot ? dotSize * 1.2 : dotSize)
            .scaleEffect(scale)
            .opacity(opacity)
            .animation(.spring(response: 0.2, dampingFraction: 0.3), value: scale)
            .animation(.spring(response: 0.2, dampingFraction: 0.3), value: opacity)
    }
}

// MARK: - Hue Picker (Used in both registration and settings)
struct HuePicker: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var paletteManager = ColorPaletteManager.shared
    @State private var dragLocation: CGPoint? = nil
    @State private var currentColor: Color = Color(hue: 0.4, saturation: 0.6, brightness: 0.9)
    
    // State variables
    @State private var hasStartedDragging: Bool = false
    @State private var lastCrossedHorizontalGuide: Bool = false
    @State private var lastCrossedVerticalGuide: Bool = false
    @State private var wasNearEdge: Bool = false
    @State private var colorName: String = "Mint Split"
    @State private var currentYFraction: Double = 0.5
    @State private var currentGridSize: CGSize = CGSize(width: 300, height: 200)
    
    private let columns = 13
    private let rows = 10
    private let dotSize: CGFloat = 6
    private let influenceRadius: CGFloat = 50
    
    // Center guide (single center dot)
    private var centerRow: Int { rows / 2 }
    private var centerCol: Int { columns / 2 }
    
    // Haptic generators
    private let lightFeedback = UIImpactFeedbackGenerator(style: .light)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            sheetMoodTextView
            sheetDotGridView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { sheetBackground }
        .onAppear {
            lightFeedback.prepare()
            notificationFeedback.prepare()
            
            // Set initial color name based on the default currentColor (which is at center)
            let name = getDynamicColorName(hue: 0.4)
            let style = getDynamicStyleName(y: 0.5)
            colorName = "\(name) \(style)"
        }
    }
    
    // MARK: - Extracted Sub-views
    
    private var sheetMoodTextView: some View {
        HStack(alignment: .top, spacing: 0) {
            (
                Text("Pick a hue, and we'll make\na ")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                + Text(colorName)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(currentColor)
                + Text(" palette for you")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            )
            .lineLimit(2)
            .minimumScaleFactor(0.75)
            .contentTransition(.numericText(countsDown: false))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: colorName)
            
            Spacer(minLength: 0)
        }
        .frame(height: 60, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 15)
    }
    
    private var sheetDotGridView: some View {
        GeometryReader { geometry in
            let gridWidth = geometry.size.width
            let gridHeight = geometry.size.height
            let spacingX = gridWidth / CGFloat(columns)
            let spacingY = gridHeight / CGFloat(rows)
            
            ZStack {
                sheetDotsGrid(geometry: geometry, spacingX: spacingX, spacingY: spacingY)
                sheetCursorView
            }
            .contentShape(Rectangle())
            .gesture(sheetDragGesture(gridWidth: gridWidth, gridHeight: gridHeight, spacingX: spacingX, spacingY: spacingY, gridSize: geometry.size))
            .coordinateSpace(name: "sheetGrid")
            .onAppear {
                currentGridSize = geometry.size
            }
            .onChange(of: geometry.size) { newSize in
                currentGridSize = newSize
            }
        }
        .padding(6)
        .background { sheetGridBackground }
        .overlay { sheetGridBorder }
        .padding(.horizontal, 15)
        .padding(.bottom, 8)
    }
    
    private func sheetDotsGrid(geometry: GeometryProxy, spacingX: CGFloat, spacingY: CGFloat) -> some View {
        ForEach(0..<rows, id: \.self) { row in
            ForEach(0..<columns, id: \.self) { col in
                let dotX = spacingX * (CGFloat(col) + 0.5)
                let dotY = spacingY * (CGFloat(row) + 0.5)
                let dotCenter = CGPoint(x: dotX, y: dotY)
                
                // Check if this is the center guide dot (single point at grid center)
                let isGuideDot = row == centerRow && col == centerCol
                
                DotView(
                    center: dotCenter,
                    dragLocation: dragLocation,
                    influenceRadius: influenceRadius,
                    gridSize: geometry.size,
                    dotSize: dotSize,
                    isGuideDot: isGuideDot,
                    vibrancy: paletteManager.vibrancy
                )
                .position(dotCenter)
            }
        }
    }
    
    @ViewBuilder
    private var sheetCursorView: some View {
        if let location = dragLocation {
            Circle()
                .fill(currentColor.opacity(0.2))
                .frame(width: 58, height: 58)
                .glassEffect(.clear.interactive(), in: .circle)
                .position(location)
                .animation(.interactiveSpring(response: 0.08, dampingFraction: 0.9), value: location)
        }
    }
    
    private func sheetDragGesture(gridWidth: CGFloat, gridHeight: CGFloat, spacingX: CGFloat, spacingY: CGFloat, gridSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Inset by cursor radius so it stays visually within the grid
                let cursorRadius: CGFloat = 29
                let clampedX = min(max(cursorRadius, value.location.x), gridWidth - cursorRadius)
                let clampedY = min(max(cursorRadius, value.location.y), gridHeight - cursorRadius)
                let newLocation = CGPoint(x: clampedX, y: clampedY)
                
                if !hasStartedDragging {
                    hasStartedDragging = true
                }
                
                // Check if crossing center guide lines (crosshair)
                let centerY = gridHeight / 2
                let centerX = gridWidth / 2
                let guideThreshold: CGFloat = spacingY * 0.5
                
                let isNearHorizontalGuide = abs(clampedY - centerY) < guideThreshold
                let isNearVerticalGuide = abs(clampedX - centerX) < guideThreshold
                
                // Trigger haptic when crossing the guides
                if isNearHorizontalGuide && !lastCrossedHorizontalGuide {
                    lightFeedback.impactOccurred(intensity: 0.4)
                }
                if isNearVerticalGuide && !lastCrossedVerticalGuide {
                    lightFeedback.impactOccurred(intensity: 0.4)
                }
                lastCrossedHorizontalGuide = isNearHorizontalGuide
                lastCrossedVerticalGuide = isNearVerticalGuide
                
                // Trigger haptic when touching edges
                let edgeThreshold: CGFloat = 15
                let nearEdge = clampedX < edgeThreshold || clampedX > gridWidth - edgeThreshold ||
                               clampedY < edgeThreshold || clampedY > gridHeight - edgeThreshold
                if nearEdge && !wasNearEdge {
                    lightFeedback.impactOccurred(intensity: 0.3)
                }
                wasNearEdge = nearEdge
                
                dragLocation = newLocation
                updateColor(at: newLocation, gridSize: gridSize)
            }
            .onEnded { _ in
                notificationFeedback.notificationOccurred(.success)
                saveSelection()
                dismiss()
            }
    }
    
    private var sheetGridBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color(.secondarySystemBackground).opacity(0.6))
    }
    
    private var sheetGridBorder: some View {
        RoundedRectangle(cornerRadius: 20)
            .strokeBorder(currentColor.opacity(0.2), lineWidth: 1)
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.3), value: currentColor)
    }
    
    private var sheetBackground: some View {
        ZStack {
            // Opaque base background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            // Subtle corner gradient - top leading to bottom trailing
            RadialGradient(
                colors: [
                    currentColor.opacity(0.25),
                    currentColor.opacity(0.08),
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()
        }
        .animation(.easeInOut(duration: 0.4), value: currentColor)
    }
    
    private func saveSelection() {
        let paletteColors = generatePalette(from: currentColor, y: currentYFraction)
        let palette = ColorPalette(
            id: 1000,
            name: colorName,
            colors: paletteColors
        )
        paletteManager.customPalette = palette
        paletteManager.selectedPalette = palette
    }
    
    private func getDynamicColorName(hue: Double) -> String {
        switch hue {
        case 0.0..<0.03: return "Scarlet"
        case 0.03..<0.06: return "Coral"
        case 0.06..<0.09: return "Orange"
        case 0.09..<0.12: return "Peach"
        case 0.12..<0.15: return "Amber"
        case 0.15..<0.18: return "Gold"
        case 0.18..<0.21: return "Yellow"
        case 0.21..<0.25: return "Lime"
        case 0.25..<0.29: return "Olive"
        case 0.29..<0.34: return "Green"
        case 0.34..<0.38: return "Emerald"
        case 0.38..<0.42: return "Mint"
        case 0.42..<0.46: return "Teal"
        case 0.46..<0.50: return "Cyan"
        case 0.50..<0.54: return "Turquoise"
        case 0.54..<0.58: return "Sky Blue"
        case 0.58..<0.62: return "Azure"
        case 0.62..<0.66: return "Cobalt"
        case 0.66..<0.70: return "Blue"
        case 0.70..<0.74: return "Sapphire"
        case 0.74..<0.78: return "Indigo"
        case 0.78..<0.82: return "Lavender"
        case 0.82..<0.86: return "Purple"
        case 0.86..<0.90: return "Violet"
        case 0.90..<0.94: return "Plum"
        case 0.94..<0.97: return "Rose"
        default: return "Crimson"
        }
    }
    
    private func getDynamicStyleName(y: Double) -> String {
        switch y {
        case 0.0..<0.20: return "Mono"
        case 0.20..<0.40: return "Analog"
        case 0.40..<0.60: return "Split"
        case 0.60..<0.80: return "Triad"
        default: return "Complement"
        }
    }
    
    private func generatePalette(from baseColor: Color, y: Double) -> [String] {
        let uiColor = UIColor(baseColor)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        var colors: [UIColor] = []
        
        switch y {
        case 0.0..<0.20:
            // Monochromatic
            colors = [
                uiColor,
                UIColor(hue: hue, saturation: max(saturation - 0.15, 0.15), brightness: min(brightness + 0.05, 1.0), alpha: alpha),
                UIColor(hue: hue, saturation: max(saturation - 0.3, 0.1), brightness: min(brightness + 0.1, 1.0), alpha: alpha),
                UIColor(hue: hue, saturation: min(saturation + 0.15, 0.9), brightness: max(brightness - 0.1, 0.4), alpha: alpha),
                UIColor(hue: hue, saturation: min(saturation + 0.3, 1.0), brightness: max(brightness - 0.2, 0.3), alpha: alpha)
            ]
        case 0.20..<0.40:
            // Analogous
            colors = [
                uiColor,
                UIColor(hue: fmod(hue + 0.083, 1.0), saturation: saturation * 0.9, brightness: min(brightness * 1.1, 1.0), alpha: alpha),
                UIColor(hue: fmod(hue + 0.917, 1.0), saturation: saturation * 0.9, brightness: min(brightness * 1.1, 1.0), alpha: alpha),
                UIColor(hue: fmod(hue + 0.041, 1.0), saturation: saturation * 0.95, brightness: min(brightness * 1.05, 1.0), alpha: alpha),
                UIColor(hue: fmod(hue + 0.959, 1.0), saturation: saturation * 0.95, brightness: min(brightness * 1.05, 1.0), alpha: alpha)
            ]
        case 0.40..<0.60:
            // Split Complementary
            colors = [
                uiColor,
                UIColor(hue: fmod(hue + 0.083, 1.0), saturation: saturation, brightness: brightness, alpha: alpha),
                UIColor(hue: fmod(hue + 0.416, 1.0), saturation: saturation * 0.8, brightness: min(brightness * 1.1, 1.0), alpha: alpha),
                UIColor(hue: fmod(hue + 0.583, 1.0), saturation: saturation * 0.8, brightness: min(brightness * 1.1, 1.0), alpha: alpha),
                UIColor(hue: fmod(hue - 0.083 + 1.0, 1.0), saturation: saturation, brightness: brightness, alpha: alpha)
            ]
        case 0.60..<0.80:
            // Triadic
            colors = [
                uiColor,
                UIColor(hue: fmod(hue + 0.333, 1.0), saturation: saturation * 0.9, brightness: brightness, alpha: alpha),
                UIColor(hue: fmod(hue + 0.667, 1.0), saturation: saturation * 0.9, brightness: brightness, alpha: alpha),
                UIColor(hue: hue, saturation: saturation * 0.6, brightness: min(brightness * 1.15, 1.0), alpha: alpha),
                UIColor(hue: fmod(hue + 0.333, 1.0), saturation: saturation * 1.1, brightness: max(brightness * 0.85, 0.4), alpha: alpha)
            ]
        default:
            // Complementary
            colors = [
                uiColor,
                UIColor(hue: hue, saturation: saturation * 0.7, brightness: min(brightness * 1.1, 1.0), alpha: alpha),
                UIColor(hue: fmod(hue + 0.5, 1.0), saturation: saturation, brightness: brightness, alpha: alpha),
                UIColor(hue: fmod(hue + 0.5, 1.0), saturation: saturation * 0.7, brightness: min(brightness * 1.1, 1.0), alpha: alpha),
                UIColor(hue: fmod(hue + 0.5, 1.0), saturation: min(saturation * 1.2, 1.0), brightness: max(brightness * 0.8, 0.4), alpha: alpha)
            ]
        }
        
        return colors.map { Color($0).toHex() }
    }
    
    private func updateColor(at location: CGPoint, gridSize: CGSize) {
        let normalizedX = location.x / gridSize.width
        let normalizedY = location.y / gridSize.height
        currentYFraction = normalizedY
        
        let interpolatedColor = interpolateColor(x: normalizedX, y: normalizedY)
        currentColor = interpolatedColor
        
        let newColorName = getDynamicColorName(hue: normalizedX)
        let newStyleName = getDynamicStyleName(y: normalizedY)
        let combined = "\(newColorName) \(newStyleName)"
        
        if combined != colorName {
            lightFeedback.impactOccurred(intensity: 0.35)
            colorName = combined
        }
    }
    
    private func interpolateColor(x: Double, y: Double) -> Color {
        let hue = x
        let minSat = 0.10 + (paletteManager.vibrancy * 0.35)
        let maxSat = 0.30 + (paletteManager.vibrancy * 0.65)
        let saturation = minSat + (y * (maxSat - minSat))
        let brightness: CGFloat = 0.98 - (paletteManager.vibrancy * 0.08)
        
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
}

// MARK: - Glass Effect Extensions
extension View {
    @ViewBuilder
    func applyGlassEffect() -> some View {
        self.glassEffect(.regular, in: .circle)
    }
}

// MARK: - Preview
#Preview("Inline Picker") {
    VStack {
        HuePicker()
            .padding()
        Spacer()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Sheet Picker") {
    HuePicker()
        .presentationDetents([.medium])
        .presentationBackground(.background)
}
