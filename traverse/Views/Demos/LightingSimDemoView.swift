//
//  LightingSimDemoView.swift
//  traverse
//
//  1:1 implementation of https://github.com/radiofun/LightingSim
//

import SwiftUI

struct LightingSimDemoView: View {
    @State private var intensity: Float = 1.5
    @State private var disperse: Float = 0.5
    @State private var rotation: Float = 0
    @State private var radius: Float = 30.0
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black.mix(with: .gray, by: 0.2), .gray.mix(with: .black, by: 0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("Lighting Simulation")
                        .font(.system(size: 14, design: .monospaced))
                        .bold()
                    Text("3D Normal Map Light Cone")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.gray)
                    HStack {
                        Text("I: \(intensity, specifier: "%.2f") / ")
                        Text("D: \(disperse, specifier: "%.2f") / ")
                        Text("R: \(radius, specifier: "%.0f")")
                    }
                    .font(.system(size: 10, design: .monospaced))
                }
                .foregroundStyle(.white)
                .textCase(.uppercase)

                ZStack {
                    Color.black
                        .frame(width: 340, height: 340)
                        .layerEffect(
                            ShaderLibrary.lightingSimulation(
                                .float2(340, 80),
                                .float(intensity),
                                .float(disperse),
                                .float(rotation),
                                .float(radius)
                            ),
                            maxSampleOffset: CGSize(width: 0, height: 0)
                        )
                        .cornerRadius(20)
                        .shadow(color: .white.opacity(0.2), radius: 1)
                        .rotationEffect(Angle(degrees: 180))
                        .animation(.spring, value: rotation)

                    Canvas { context, size in
                        let center = CGPoint(x: 170, y: 40)
                        let beamLength: CGFloat = 340
                        let baseAngle = Float.pi / 2.0
                        let angle = baseAngle + rotation
                        
                        for r in stride(from: 40.0, through: 400.0, by: 40.0) {
                            let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                            let circlePath = Path(ellipseIn: rect)
                            context.stroke(circlePath, with: .color(.white.opacity(0.05)), style: StrokeStyle(lineWidth: 1))
                        }
                        
                        let dir = CGPoint(x: CGFloat(cos(angle)), y: CGFloat(sin(angle)))
                        let perp = CGPoint(x: -dir.y, y: dir.x)
                        let spreadFactor = 2.0 * disperse
                        let outerSpreadFactor = spreadFactor * 4.0
                        
                        func pathFor(spread: Float, color: Color, style: StrokeStyle = StrokeStyle()) {
                            var leftLine = Path()
                            var rightLine = Path()
                            let steps = 100
                            for i in 0...steps {
                                let t = Float(i) / Float(steps)
                                let dist = CGFloat(t) * beamLength
                                let t_mapped = t / 0.2
                                let clamped_t_mapped = max(0, min(1, t_mapped))
                                let startSmoothing = clamped_t_mapped * clamped_t_mapped * (3 - 2 * clamped_t_mapped)
                                let w0 = radius
                                let currentWidth = w0 + Float(dist) * spread * startSmoothing
                                
                                let pointOnAxis = CGPoint(x: center.x + dir.x * dist, y: center.y + dir.y * dist)
                                let offset = CGPoint(x: perp.x * CGFloat(currentWidth), y: perp.y * CGFloat(currentWidth))
                                
                                let leftP = CGPoint(x: pointOnAxis.x + offset.x, y: pointOnAxis.y + offset.y)
                                let rightP = CGPoint(x: pointOnAxis.x - offset.x, y: pointOnAxis.y - offset.y)
                                
                                if i == 0 {
                                    leftLine.move(to: leftP)
                                    rightLine.move(to: rightP)
                                } else {
                                    leftLine.addLine(to: leftP)
                                    rightLine.addLine(to: rightP)
                                }
                            }
                            context.stroke(leftLine, with: .color(color), style: style)
                            context.stroke(rightLine, with: .color(color), style: style)
                        }
                        
                        pathFor(spread: spreadFactor, color: .yellow, style: StrokeStyle(lineWidth: 0.5, dash: [2]))
                        pathFor(spread: outerSpreadFactor, color: .white, style: StrokeStyle(lineWidth: 0.5, dash: [2]))
                    }
                    .frame(width: 340, height: 340)
                    .cornerRadius(20)
                    .rotationEffect(Angle(degrees: 180))
                    .allowsHitTesting(false)
                }

                VStack(spacing: 10) {
                    VStack(alignment: .leading) {
                        Text("Intensity")
                        Slider(value: $intensity, in: 0...3)
                    }
                    VStack(alignment: .leading) {
                        Text("Disperse")
                        Slider(value: $disperse, in: 0.1...1)
                    }
                    VStack(alignment: .leading) {
                        Text("Radius")
                        Slider(value: $radius, in: 0...120)
                    }
                }
                .foregroundStyle(.white)
                .font(.system(size: 11, design: .monospaced))
                .textCase(.uppercase)
                .tint(.yellow)
                .padding()
                .background(.gray.opacity(0.15))
                .cornerRadius(16)
                .padding(.horizontal)
            }
        }
    }
}

#Preview {
    LightingSimDemoView()
}
