//
//  DomainWarpingDemoView.swift
//  traverse
//
//  1:1 implementation of https://github.com/radiofun/Metal-Domain-Warping
//

import SwiftUI

struct DomainWarpingDemoView: View {
    @State private var progress: Double = 0.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                Text("Voice Mode Domain Warping")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                LinearGradient(
                    colors: [.white.mix(with: .blue, by: 0.1), .blue],
                    startPoint: UnitPoint(x: 0.3, y: 0.3),
                    endPoint: UnitPoint(x: 0.4, y: 0.6)
                )
                .frame(width: 340, height: 340)
                .layerEffect(
                    ShaderLibrary.fractalNoiseBlueWhite(
                        .boundingRect,
                        .float(progress),
                        .float(2.0)
                    ),
                    maxSampleOffset: .zero
                )
                .mask(
                    Circle()
                        .frame(width: 280, height: 280)
                )
                .shadow(color: .blue.opacity(0.6), radius: 30)

                Text("OpenAI Voice Mode Fluid Shader")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.gray)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 30).repeatForever(autoreverses: true)) {
                progress = 6
            }
        }
    }
}

#Preview {
    DomainWarpingDemoView()
}
