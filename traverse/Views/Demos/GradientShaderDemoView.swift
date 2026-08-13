//
//  GradientShaderDemoView.swift
//  traverse
//
//  1:1 implementation of https://github.com/radiofun/GradientShader
//

import SwiftUI

struct GradientShaderDemoView: View {
    var body: some View {
        ZStack {
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100)
                
                Color.black
                    .layerEffect(
                        ShaderLibrary.noisyGradient(
                            .boundingRect,
                            .float(time)
                        ),
                        maxSampleOffset: .zero
                    )
                    .ignoresSafeArea()
            }

            VStack {
                Spacer()
                Text("Noisy Gradient Mesh Shader")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    GradientShaderDemoView()
}
