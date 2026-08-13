//
//  ArcSelectorDemoView.swift
//  traverse
//
//  1:1 implementation of https://github.com/radiofun/ArcSelector
//

import SwiftUI

struct ArcMenuConfig {
    var radius: CGFloat = 210
    var lineHeight: CGFloat = 46
    var lineGap: CGFloat = 16
    var angleRange: ClosedRange<Double> = 218...326
}

struct ArcBackground: Shape {
    var startAngle: Angle
    var endAngle: Angle

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startAngle.degrees, endAngle.degrees) }
        set {
            startAngle = .degrees(newValue.first)
            endAngle   = .degrees(newValue.second)
        }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        let radius = rect.width / 2
        var p = Path()
        p.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: true
        )
        return p.strokedPath(
            StrokeStyle(lineWidth: rect.height, lineCap: .round)
        )
    }
}

private struct ArcTextView<Content: View>: View, Animatable {
    var startAngle: Angle
    var endAngle: Angle
    var progress: Double
    var radius: CGFloat
    @ViewBuilder var content: () -> Content

    var animatableData: AnimatablePair<
        Double, AnimatablePair<Double, Double>
    > {
        get {
            AnimatablePair(
                startAngle.degrees,
                AnimatablePair(endAngle.degrees, progress)
            )
        }
        set {
            startAngle = .degrees(newValue.first)
            endAngle   = .degrees(newValue.second.first)
            progress   = newValue.second.second
        }
    }

    var body: some View {
        let sweep   = endAngle.degrees - startAngle.degrees
        let degrees = startAngle.degrees + sweep * progress
        let angle   = Angle(degrees: degrees)

        content()
            .frame(width: 30, height: 60)
            .rotationEffect(Angle(degrees: angle.degrees))
            .offset(
                x: (radius / 2 * CGFloat(cos(angle.radians)) + 2),
                y: (radius / 2 * CGFloat(sin(angle.radians)) + 15)
            )
    }
}

struct BackNumberView: View {
    @State private var radius: CGFloat = 210
    @State private var customangle: CGFloat = 90
    let numbers: [CGFloat]
    var firstangle: CGFloat
    var spacing: CGFloat
    var onTap: ((CGFloat) -> Void)? = nil

    var body: some View {
        ZStack {
            ZStack {
                ForEach(Array(numbers.enumerated()), id: \.offset) { index, number in
                    let angle = Angle(degrees: -firstangle + Double(index) / Double(numbers.count) * spacing)
                    ZStack {
                        Text("\(number, specifier: "%.1f")")
                            .rotationEffect(Angle(degrees: customangle))
                            .font(.system(size: 14, design: .monospaced))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 60)
                    .cornerRadius(8)
                    .rotationEffect(Angle(degrees: angle.degrees))
                    .offset(x: radius / 2 * cos(angle.radians), y: radius / 2 * sin(angle.radians))
                    .onTapGesture {
                        onTap?(number)
                    }
                }
            }
            .frame(width: radius, height: radius)
        }
    }
}

struct ArcSelectorDemoView: View {
    private let config = ArcMenuConfig()
    @State private var startAngle: Double = 218
    @State private var isToggle: Bool = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                Spacer()

                ZStack {
                    ArcBackground(startAngle: Angle(degrees: -28), endAngle: Angle(degrees: 210))
                        .fill(.black)
                        .frame(width: config.radius, height: config.lineHeight)
                        .opacity(isToggle ? 1 : 0)

                    BackNumberView(
                        numbers: [1, 2, 3, 4],
                        firstangle: 142,
                        spacing: 140
                    ) { selected in
                        withAnimation(.spring(.bouncy)) {
                            let target = config.angleRange.lowerBound + 36 * Double(Int(selected) - 1)
                            startAngle = target
                        }
                    }
                    .offset(y: 24)

                    ArcBackground(startAngle: Angle(degrees: startAngle + 5), endAngle: Angle(degrees: startAngle - 5))
                        .fill(.white)
                        .offset(y: config.lineGap / 2)
                        .frame(width: config.radius, height: config.lineHeight - config.lineGap)
                        .shadow(radius: 10)

                    ArcTextView(
                        startAngle: Angle(degrees: startAngle + 5),
                        endAngle:   Angle(degrees: startAngle - 5),
                        progress:   0.5,
                        radius:     config.radius
                    ) {
                        Text(
                            String(
                                format: "%.1f",
                                convertRange(
                                    value: startAngle,
                                    minvalue: config.angleRange.lowerBound,
                                    maxvalue: config.angleRange.upperBound,
                                    minrange: 1.0,
                                    maxrange: 4.0
                                )
                            )
                        )
                        .font(.system(size: 14, design: .monospaced))
                        .rotationEffect(Angle(degrees: 90))
                    }
                    .offset(y: config.lineGap / 2)
                }
                .frame(width: config.radius + 90, height: config.radius - 10)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            startAngle = convertRange(
                                value: value.translation.width,
                                minvalue: 0,
                                maxvalue: 100,
                                minrange: config.angleRange.lowerBound,
                                maxrange: config.angleRange.upperBound
                            )
                        }
                )

                Spacer()
                
                Text("Drag horizontally or tap numbers to select")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.gray)
                    .padding(.bottom, 40)
            }
        }
    }
}

private func convertRange(value: Double, minvalue: Double, maxvalue: Double, minrange: Double, maxrange: Double) -> Double {
    let inputRange: (min: Double, max: Double) = (minvalue, maxvalue)
    let outputRange: (min: Double, max: Double) = (minrange, maxrange)
    let clampedValue = max(min(value, inputRange.max), inputRange.min)
    return outputRange.min + (clampedValue - inputRange.min) * (outputRange.max - outputRange.min) / (inputRange.max - inputRange.min)
}

#Preview {
    ArcSelectorDemoView()
}
