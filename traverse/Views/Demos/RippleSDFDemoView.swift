//
//  RippleSDFDemoView.swift
//  traverse
//
//  1:1 reproduction of radiofun/ripplesdf
//

import SwiftUI
import Combine

struct RippleSDFDemoView: View {
    @State private var time: Float = 0
    @State private var dragPoint: CGPoint = CGPoint(x: 200, y: 350)
    @State private var radius: Float = 0.35
    @State private var cornerRadius: Float = 24

    let timer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient grid
                LinearGradient(
                    colors: [.indigo, .purple, .pink, .orange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    Text("Ripple SDF Demo")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.top, 40)

                    Text("Drag anywhere to move the ripple origin")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))

                    Spacer()

                    // Visual Card that receives the layer effect
                    ZStack {
                        RoundedRectangle(cornerRadius: 32)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 32)
                                    .stroke(.white.opacity(0.4), lineWidth: 1.5)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)

                        VStack(spacing: 12) {
                            Image(systemName: "water.waves")
                                .font(.system(size: 48, weight: .semibold))
                                .foregroundStyle(.white)

                            Text("Interactive Ripple SDF")
                                .font(.headline)
                                .foregroundStyle(.white)

                            Text("Drag Point: (\(Int(dragPoint.x)), \(Int(dragPoint.y)))")
                                .font(.caption)
                                .fontDesign(.monospaced)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .frame(width: 300, height: 380)
                    .layerEffect(
                        ShaderLibrary.outerRippleRoundedRect(
                            .boundingRect,
                            .float4(cornerRadius, cornerRadius, cornerRadius, cornerRadius),
                            .float(radius),
                            .float2(dragPoint),
                            .float(time)
                        ),
                        maxSampleOffset: CGSize(width: 32, height: 32)
                    )

                    Spacer()
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragPoint = value.location
                    }
            )
            .onAppear {
                dragPoint = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .onReceive(timer) { _ in
            time += 0.03
        }
    }
}

#Preview {
    RippleSDFDemoView()
}
