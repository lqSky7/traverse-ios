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
        
        // X = Hue (0-1 maps to full color spectrum)
        // Y = Saturation (top = very pastel/0.3, bottom = soft pastel/0.6)
        let hue = normalizedX
        let saturation = 0.3 + (normalizedY * 0.3) // 0.3 to 0.6 (pastel only)
        let brightness: CGFloat = 0.95
        
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
    
    // Haptic tracking state
    @State private var currentMoodIndex: Int = 0
    @State private var hasStartedDragging: Bool = false
    @State private var lastCrossedHorizontalGuide: Bool = false
    @State private var lastCrossedVerticalGuide: Bool = false
    @State private var wasNearEdge: Bool = false
    
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
    
    // Mood names instead of jokes - matches expected design
    private let moodNames = [
        "Gloom",
        "Serenity",
        "Warmth",
        "Joy",
        "Wonder",
        "Nostalgia",
        "Peace",
        "Energy",
        "Mystery",
        "Hope",
        "Calm",
        "Bliss",
        "Delight",
        "Whimsy",
        "Clarity"
    ]
    
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
        }
    }
    
    // MARK: - Extracted Sub-views
    
    private var sheetMoodTextView: some View {
        HStack(spacing: 0) {
            Text("Pick a hue, and we'll make\na ")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            + Text(moodNames[currentMoodIndex])
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(currentColor)
            + Text(" palette for you")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.primary)
        }
        .contentTransition(.numericText(countsDown: false))
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentMoodIndex)
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
                    isGuideDot: isGuideDot
                )
                .position(dotCenter)
            }
        }
    }
    
    @ViewBuilder
    private var sheetCursorView: some View {
        if let location = dragLocation {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 40, height: 40)
                .position(location)
                .animation(.interactiveSpring(response: 0.08, dampingFraction: 0.9), value: location)
        }
    }
    
    private func sheetDragGesture(gridWidth: CGFloat, gridHeight: CGFloat, spacingX: CGFloat, spacingY: CGFloat, gridSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Inset by cursor radius so it stays visually within the grid
                let cursorRadius: CGFloat = 22
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
                    currentMoodIndex = (currentMoodIndex + 1) % moodNames.count
                }
                if isNearVerticalGuide && !lastCrossedVerticalGuide {
                    lightFeedback.impactOccurred(intensity: 0.4)
                    currentMoodIndex = (currentMoodIndex + 1) % moodNames.count
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
        let paletteColors = generatePalette(from: currentColor)
        let palette = ColorPalette(
            id: 1000,
            name: moodNames[currentMoodIndex],
            colors: paletteColors
        )
        paletteManager.customPalette = palette
        paletteManager.selectedPalette = palette
    }
    
    private func generatePalette(from baseColor: Color) -> [String] {
        let uiColor = UIColor(baseColor)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // Analogous color scheme with variations for better harmony
        let colors: [UIColor] = [
            // Base color
            uiColor,
            // Analogous +30° - slightly lighter
            UIColor(hue: fmod(hue + 0.083, 1.0), saturation: saturation * 0.9, brightness: min(brightness * 1.1, 1.0), alpha: alpha),
            // Analogous -30° - slightly lighter
            UIColor(hue: fmod(hue + 0.917, 1.0), saturation: saturation * 0.9, brightness: min(brightness * 1.1, 1.0), alpha: alpha),
            // Complementary with reduced saturation for balance
            UIColor(hue: fmod(hue + 0.5, 1.0), saturation: saturation * 0.5, brightness: min(brightness * 1.15, 1.0), alpha: alpha),
            // Triadic accent - muted
            UIColor(hue: fmod(hue + 0.333, 1.0), saturation: saturation * 0.6, brightness: brightness, alpha: alpha)
        ]
        
        return colors.map { Color($0).toHex() }
    }
    
    private func updateColor(at location: CGPoint, gridSize: CGSize) {
        let normalizedX = location.x / gridSize.width
        let normalizedY = location.y / gridSize.height
        
        let interpolatedColor = interpolateColor(x: normalizedX, y: normalizedY)
        currentColor = interpolatedColor
    }
    
    private func interpolateColor(x: Double, y: Double) -> Color {
        // X = Hue (0-1 maps to full 360° color spectrum)
        // Y = Saturation (top = very pastel/0.3, bottom = soft pastel/0.6)
        let hue = x
        let saturation = 0.3 + (y * 0.3) // 0.3 to 0.6 (pastel only)
        let brightness: CGFloat = 0.95
        
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
