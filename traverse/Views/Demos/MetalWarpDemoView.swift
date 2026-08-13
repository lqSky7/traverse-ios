//
//  MetalWarpDemoView.swift
//  traverse
//
//  1:1 implementation of https://github.com/radiofun/MetalWarp
//

import SwiftUI

struct MetalWarpDemoView: View {
    @State private var position = CGPoint(x: 180, y: 180)
    @State private var imageSize = CGSize(width: 340, height: 340)
    @State private var warpfactor: Double = 1.0
    @State private var intensity: Double = 0.5

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                Spacer()

                ZStack {
                    LinearGradient(
                        colors: [.orange, .pink, .purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.white)
                            Text("DRAG TO WARP")
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                    )
                    .frame(width: imageSize.width, height: imageSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .layerEffect(
                        ShaderLibrary.warp(
                            .float2(imageSize),
                            .float2(position),
                            .float(warpfactor),
                            .float(intensity)
                        ), maxSampleOffset: CGSize(width: 320, height: 360)
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in position = value.location }
                    )
                }

                Spacer()

                VStack(spacing: 8) {
                    Text("Warp: \(String(format: "%.2f", warpfactor)), Strength: \(String(format: "%.2f", intensity))")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white)

                    HStack {
                        Text("Warp")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(width: 50)
                        Slider(value: $warpfactor, in: 0...5)
                            .tint(.gray)
                    }

                    HStack {
                        Text("Str")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(width: 50)
                        Slider(value: $intensity, in: 0...1)
                            .tint(.gray)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .padding()
            }
        }
    }
}

#Preview {
    MetalWarpDemoView()
}
