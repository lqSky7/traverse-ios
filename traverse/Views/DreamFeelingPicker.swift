import SwiftUI

// MARK: - Hue Corner Colors
struct HueCorners {
    // Corner colors for the gradient grid
    static let topLeft = Color(hex: "7B68EE")      // Purple/Blue
    static let topRight = Color(hex: "FFB347")     // Yellow/Orange
    static let bottomLeft = Color(hex: "20B2AA")   // Teal
    static let bottomRight = Color(hex: "98D8AA")  // Green
}

// MARK: - Hue Picker
struct HuePicker: View {
    @State private var dragLocation: CGPoint? = nil
    @State private var currentColor: Color = HueCorners.bottomRight
    @State private var lastQuadrant: Int = -1
    @State private var currentJokeIndex: Int = 0
    @State private var hasStartedDragging: Bool = false
    @State private var lastGridX: Int = -1
    @State private var lastGridY: Int = -1
    
    private let columns = 12
    private let rows = 10
    private let dotSize: CGFloat = 8
    private let influenceRadius: CGFloat = 60
    
    // Haptic generators
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let lightFeedback = UIImpactFeedbackGenerator(style: .light)
    private let mediumFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let heavyFeedback = UIImpactFeedbackGenerator(style: .heavy)
    
    // Dad joke color picker names
    private let colorJokes = [
        "Hue Dunit?",
        "Feeling Chroma-tic",
        "Orange You Glad",
        "Color Me Impressed",
        "Fifty Shades of Yay",
        "ROY G. BIV's Crib",
        "Pigment of Imagination",
        "Tint There, Done That",
        "The Hue-man Touch",
        "Shade-y Business",
        "A Dye-lemma",
        "Prism Break",
        "In Living Color",
        "Chromatic Chaos",
        "The Palette Cleanser"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Dad joke with numericText animation
            Text(colorJokes[currentJokeIndex])
                .font(.system(.body, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(currentColor)
                .contentTransition(.numericText())
                .animation(.spring(duration: 3.5), value: currentJokeIndex)
                .padding(.horizontal, 4)
            
            // Dot Grid
            GeometryReader { geometry in
                let gridWidth = geometry.size.width
                let gridHeight = geometry.size.height
                let spacingX = gridWidth / CGFloat(columns)
                let spacingY = gridHeight / CGFloat(rows)
                
                ZStack {
                    // Dots Grid
                    ForEach(0..<rows, id: \.self) { row in
                        ForEach(0..<columns, id: \.self) { col in
                            let dotX = spacingX * (CGFloat(col) + 0.5)
                            let dotY = spacingY * (CGFloat(row) + 0.5)
                            let dotCenter = CGPoint(x: dotX, y: dotY)
                            
                            DotView(
                                center: dotCenter,
                                dragLocation: dragLocation,
                                influenceRadius: influenceRadius,
                                gridSize: geometry.size,
                                dotSize: dotSize
                            )
                            .position(dotCenter)
                        }
                    }
                    
                    // Cursor - Liquid Glass Circle
                    if let location = dragLocation {
                        Circle()
                            .frame(width: 28, height: 28)
                            .glassEffect(.clear.interactive(), in: .circle)
                            .position(location)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: location)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let clampedX = min(max(0, value.location.x), gridWidth)
                            let clampedY = min(max(0, value.location.y), gridHeight)
                            
                            // Initial touch haptic
                            if !hasStartedDragging {
                                hasStartedDragging = true
                                mediumFeedback.impactOccurred(intensity: 0.6)
                            }
                            
                            // Grid line crossing haptic
                            let gridX = Int(clampedX / spacingX)
                            let gridY = Int(clampedY / spacingY)
                            if (gridX != lastGridX || gridY != lastGridY) && lastGridX != -1 {
                                lightFeedback.impactOccurred(intensity: 0.5)
                            }
                            lastGridX = gridX
                            lastGridY = gridY
                            
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragLocation = CGPoint(x: clampedX, y: clampedY)
                            }
                            
                            updateColor(
                                at: CGPoint(x: clampedX, y: clampedY),
                                gridSize: geometry.size
                            )
                        }
                        .onEnded { _ in
                            // Confirmation haptic on release
                            mediumFeedback.impactOccurred(intensity: 0.8)
                            hasStartedDragging = false
                            lastGridX = -1
                            lastGridY = -1
                        }
                )
                .coordinateSpace(name: "grid")
            }
            .frame(height: 200)
            .padding(20)
            .background {
                // LIQUID GLASS BACKGROUND
                RoundedRectangle(cornerRadius: 32)
                    .fill(.clear)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 32))
            }
            .overlay {
                // Subtle border
                RoundedRectangle(cornerRadius: 32)
                    .strokeBorder(currentColor.opacity(0.3), lineWidth: 1)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.3), value: currentColor)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 4)
        .background {
            // Outer card background with color glow
            RoundedRectangle(cornerRadius: 36)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 36)
                        .fill(currentColor.opacity(0.15))
                        .blur(radius: 40)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 36))
        .onAppear {
            selectionFeedback.prepare()
            lightFeedback.prepare()
            mediumFeedback.prepare()
            heavyFeedback.prepare()
        }
    }
    
    private func updateColor(at location: CGPoint, gridSize: CGSize) {
        let normalizedX = location.x / gridSize.width
        let normalizedY = location.y / gridSize.height
        
        // Cycle joke on quadrant change - immediate update
        let quadrant = (normalizedX < 0.5 ? 0 : 1) + (normalizedY < 0.5 ? 0 : 2)
        if quadrant != lastQuadrant {
            lastQuadrant = quadrant
            currentJokeIndex = (currentJokeIndex + 1) % colorJokes.count
            heavyFeedback.impactOccurred(intensity: 1.0)
        }
        
        // Bilinear color interpolation
        let interpolatedColor = interpolateColor(x: normalizedX, y: normalizedY)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            currentColor = interpolatedColor
        }
    }
    
    private func interpolateColor(x: Double, y: Double) -> Color {
        let topColor = blendColors(HueCorners.topLeft, HueCorners.topRight, ratio: x)
        let bottomColor = blendColors(HueCorners.bottomLeft, HueCorners.bottomRight, ratio: x)
        return blendColors(topColor, bottomColor, ratio: y)
    }
    
    private func blendColors(_ color1: Color, _ color2: Color, ratio: Double) -> Color {
        let uiColor1 = UIColor(color1)
        let uiColor2 = UIColor(color2)
        
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        uiColor1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uiColor2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let r = r1 + (r2 - r1) * ratio
        let g = g1 + (g2 - g1) * ratio
        let b = b1 + (b2 - b1) * ratio
        let a = a1 + (a2 - a1) * ratio
        
        return Color(UIColor(red: r, green: g, blue: b, alpha: a))
    }
}

// MARK: - Dot View
struct DotView: View {
    let center: CGPoint
    let dragLocation: CGPoint?
    let influenceRadius: CGFloat
    let gridSize: CGSize
    let dotSize: CGFloat
    
    private var distance: CGFloat {
        guard let location = dragLocation else { return .infinity }
        let dx = center.x - location.x
        let dy = center.y - location.y
        return sqrt(dx * dx + dy * dy)
    }
    
    private var scale: CGFloat {
        guard dragLocation != nil else { return 0.3 }
        let normalized = distance / influenceRadius
        return max(0.3, min(2.0, 2.0 - normalized))
    }
    
    private var opacity: CGFloat {
        guard dragLocation != nil else { return 0.3 }
        let normalized = distance / influenceRadius
        return max(0.3, min(1.0, 1.0 - normalized * 0.7))
    }
    
    private var dotColor: Color {
        guard dragLocation != nil else { return .gray }
        
        let normalizedX = center.x / gridSize.width
        let normalizedY = center.y / gridSize.height
        
        let topColor = blendColors(HueCorners.topLeft, HueCorners.topRight, ratio: normalizedX)
        let bottomColor = blendColors(HueCorners.bottomLeft, HueCorners.bottomRight, ratio: normalizedX)
        return blendColors(topColor, bottomColor, ratio: normalizedY)
    }
    
    private func blendColors(_ color1: Color, _ color2: Color, ratio: Double) -> Color {
        let uiColor1 = UIColor(color1)
        let uiColor2 = UIColor(color2)
        
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        uiColor1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uiColor2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let r = r1 + (r2 - r1) * ratio
        let g = g1 + (g2 - g1) * ratio
        let b = b1 + (b2 - b1) * ratio
        let a = a1 + (a2 - a1) * ratio
        
        return Color(UIColor(red: r, green: g, blue: b, alpha: a))
    }
    
    var body: some View {
        Circle()
            .fill(dotColor)
            .frame(width: dotSize, height: dotSize)
            .scaleEffect(scale)
            .opacity(opacity)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: scale)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: opacity)
    }
}

// MARK: - Hue Picker Sheet (Half-screen presentation)
struct HuePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var paletteManager = ColorPaletteManager.shared
    @State private var dragLocation: CGPoint? = nil
    @State private var currentColor: Color = HueCorners.bottomRight
    
    // Haptic tracking state
    @State private var lastQuadrant: Int = -1
    @State private var currentJokeIndex: Int = 0
    @State private var hasStartedDragging: Bool = false
    @State private var lastGridX: Int = -1
    @State private var lastGridY: Int = -1
    
    private let columns = 12
    private let rows = 10
    private let dotSize: CGFloat = 10
    private let influenceRadius: CGFloat = 70
    
    // Haptic generators
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let lightFeedback = UIImpactFeedbackGenerator(style: .light)
    private let mediumFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let heavyFeedback = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    // Dad joke color picker names
    private let colorJokes = [
        "Hue Dunit?",
        "Feeling Chroma-tic",
        "Orange You Glad",
        "Color Me Impressed",
        "Fifty Shades of Yay",
        "ROY G. BIV's Crib",
        "Pigment of Imagination",
        "Tint There, Done That",
        "The Hue-man Touch",
        "Shade-y Business",
        "A Dye-lemma",
        "Prism Break",
        "In Living Color",
        "Chromatic Chaos",
        "The Palette Cleanser"
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            // Header text with numericText animation
            Text(colorJokes[currentJokeIndex])
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(currentColor)
                .contentTransition(.numericText())
                .animation(.spring(duration: 3.5), value: currentJokeIndex)
                .padding(.top, 24)
            
            // Dot Grid - fills remaining space
            GeometryReader { geometry in
                let gridWidth = geometry.size.width
                let gridHeight = geometry.size.height
                let spacingX = gridWidth / CGFloat(columns)
                let spacingY = gridHeight / CGFloat(rows)
                
                ZStack {
                    // Dots Grid
                    ForEach(0..<rows, id: \.self) { row in
                        ForEach(0..<columns, id: \.self) { col in
                            let dotX = spacingX * (CGFloat(col) + 0.5)
                            let dotY = spacingY * (CGFloat(row) + 0.5)
                            let dotCenter = CGPoint(x: dotX, y: dotY)
                            
                            DotView(
                                center: dotCenter,
                                dragLocation: dragLocation,
                                influenceRadius: influenceRadius,
                                gridSize: geometry.size,
                                dotSize: dotSize
                            )
                            .position(dotCenter)
                        }
                    }
                    
                    // Cursor - Liquid Glass Circle
                    if let location = dragLocation {
                        // Outer glow ring
                        Circle()
                            .fill(currentColor.opacity(0.15))
                            .frame(width: 50, height: 50)
                            .blur(radius: 10)
                            .position(location)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: location)
                        
                        // Interactive liquid glass orb
                        Circle()
                            .fill(.clear)
                            .frame(width: 28, height: 28)
                            .glassEffect(.clear.interactive(), in: .circle)
                            .position(location)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: location)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let clampedX = min(max(0, value.location.x), gridWidth)
                            let clampedY = min(max(0, value.location.y), gridHeight)
                            let newLocation = CGPoint(x: clampedX, y: clampedY)
                            
                            // Initial touch haptic
                            if !hasStartedDragging {
                                hasStartedDragging = true
                                mediumFeedback.impactOccurred(intensity: 0.6)
                            }
                            
                            // Grid line crossing haptic
                            let gridX = Int(clampedX / spacingX)
                            let gridY = Int(clampedY / spacingY)
                            if (gridX != lastGridX || gridY != lastGridY) && lastGridX != -1 {
                                lightFeedback.impactOccurred(intensity: 0.5)
                            }
                            lastGridX = gridX
                            lastGridY = gridY
                            
                            // Quadrant change logic - immediate update
                            let quadrant = (clampedX < gridWidth / 2 ? 0 : 1) + (clampedY < gridHeight / 2 ? 0 : 2)
                            
                            if quadrant != lastQuadrant {
                                lastQuadrant = quadrant
                                currentJokeIndex = (currentJokeIndex + 1) % colorJokes.count
                                heavyFeedback.impactOccurred(intensity: 1.0)
                            }
                            
                            // Edge zone haptic
                            let edgeThreshold: CGFloat = 25
                            let nearEdge = clampedX < edgeThreshold || clampedX > gridWidth - edgeThreshold ||
                                           clampedY < edgeThreshold || clampedY > gridHeight - edgeThreshold
                            if nearEdge {
                                selectionFeedback.selectionChanged()
                            }
                            
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragLocation = newLocation
                            }
                            
                            updateColor(
                                at: newLocation,
                                gridSize: geometry.size
                            )
                        }
                        .onEnded { _ in
                            // Auto-save selection when user releases
                            notificationFeedback.notificationOccurred(.success)
                            mediumFeedback.impactOccurred(intensity: 0.8)
                            saveSelection()
                            dismiss()
                        }
                )
                .coordinateSpace(name: "sheetGrid")
            }
            .padding(20)
            .background {
                // LIQUID GLASS BACKGROUND
                RoundedRectangle(cornerRadius: 32)
                    .fill(.clear)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 32))
            }
            .overlay {
                // Subtle border
                RoundedRectangle(cornerRadius: 32)
                    .strokeBorder(currentColor.opacity(0.3), lineWidth: 1)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.3), value: currentColor)
            }
            .padding(.horizontal)
            .padding(.bottom, 4)
        }
        .background {
            LinearGradient(
                colors: [
                    currentColor.opacity(0.55),
                    currentColor.opacity(0.15),
                    .clear
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .blur(radius: 60)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.4), value: currentColor)
        }
        .onAppear {
            selectionFeedback.prepare()
            lightFeedback.prepare()
            mediumFeedback.prepare()
            heavyFeedback.prepare()
            notificationFeedback.prepare()
        }
    }
    
    private func saveSelection() {
        let paletteColors = generatePalette(from: currentColor)
        let palette = ColorPalette(
            id: 1000,
            name: colorJokes[currentJokeIndex],
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
        
        let colors: [UIColor] = [
            uiColor,
            UIColor(hue: fmod(hue + 0.083, 1.0), saturation: saturation * 0.85, brightness: min(brightness * 1.15, 1.0), alpha: alpha),
            UIColor(hue: fmod(hue + 0.917, 1.0), saturation: saturation * 0.85, brightness: min(brightness * 1.15, 1.0), alpha: alpha),
            UIColor(hue: fmod(hue + 0.5, 1.0), saturation: saturation * 0.7, brightness: brightness, alpha: alpha),
            UIColor(hue: fmod(hue + 0.417, 1.0), saturation: saturation * 0.8, brightness: min(brightness * 1.1, 1.0), alpha: alpha)
        ]
        
        return colors.map { Color($0).toHex() }
    }
    
    private func updateColor(at location: CGPoint, gridSize: CGSize) {
        let normalizedX = location.x / gridSize.width
        let normalizedY = location.y / gridSize.height
        
        let interpolatedColor = interpolateColor(x: normalizedX, y: normalizedY)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            currentColor = interpolatedColor
        }
    }
    
    private func interpolateColor(x: Double, y: Double) -> Color {
        let topColor = blendColors(HueCorners.topLeft, HueCorners.topRight, ratio: x)
        let bottomColor = blendColors(HueCorners.bottomLeft, HueCorners.bottomRight, ratio: x)
        return blendColors(topColor, bottomColor, ratio: y)
    }
    
    private func blendColors(_ color1: Color, _ color2: Color, ratio: Double) -> Color {
        let uiColor1 = UIColor(color1)
        let uiColor2 = UIColor(color2)
        
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        uiColor1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uiColor2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let r = r1 + (r2 - r1) * ratio
        let g = g1 + (g2 - g1) * ratio
        let b = b1 + (b2 - b1) * ratio
        let a = a1 + (a2 - a1) * ratio
        
        return Color(UIColor(red: r, green: g, blue: b, alpha: a))
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
    HuePickerSheet()
        .presentationDetents([.medium])
        .presentationBackground(.ultraThinMaterial)
}
