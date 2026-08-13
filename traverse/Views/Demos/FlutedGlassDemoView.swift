//
//  FlutedGlassDemoView.swift
//  traverse
//
//  1:1 implementation of https://github.com/radiofun/flutedglasseffectmetal
//

import SwiftUI

struct FlutedGlassDemoView: View {
    @State private var progress = 0.0
    @State private var amplitude = 0.0

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            LinearGradient(
                colors: [.purple, .indigo, .cyan, .orange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                VStack {
                    Text("FLUTED GLASS")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("Metal Shader Effect")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                }
            )
            .frame(width: 340, height: 340)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .layerEffect(
                ShaderLibrary.fractalGlassEffect(
                    .boundingRect,
                    .float(progress),
                    .float(amplitude)
                ),
                maxSampleOffset: .zero
            )

            VStack {
                Spacer()
                VStack(spacing: 12) {
                    HStack {
                        Text("p: \(progress, specifier: "%.2f")")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(width: 70, alignment: .leading)
                        Slider(value: $progress, in: 0...2)
                            .tint(.white)
                    }
                    HStack {
                        Text("a: \(amplitude, specifier: "%.2f")")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(width: 70, alignment: .leading)
                        Slider(value: $amplitude, in: 0...2)
                            .tint(.white)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
            }
            .padding()
        }
    }
}

#Preview {
    FlutedGlassDemoView()
}
