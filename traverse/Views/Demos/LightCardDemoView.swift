//
//  LightCardDemoView.swift
//  traverse
//
//  1:1 implementation of https://github.com/radiofun/LightCard
//

import SwiftUI

struct LightCardDemoView: View {
    @State private var progress: CGFloat = 0.05
    @State private var dragp = CGPoint(x: 320 / 2, y: 440 / 2)

    var body: some View {
        let rotationAngleX = Angle(degrees: Double(dragp.x - 160) / 10)
        let rotationAngleY = Angle(degrees: Double(dragp.y - 220) / 50)
        let cardsize = CGSize(width: 320, height: 440)

        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                Spacer()

                ZStack {
                    ZStack {
                        LinearGradient(
                            colors: [.indigo, .purple, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .overlay(
                            VStack(spacing: 16) {
                                Image(systemName: "light.beacon.max")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.white)
                                Text("LIGHT CARD")
                                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                                Text("Interactive 3D Spotlight")
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        )
                    }
                    .frame(width: cardsize.width, height: cardsize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .layerEffect(
                        ShaderLibrary.splash(
                            .boundingRect,
                            .float2(dragp),
                            .float(progress)
                        ),
                        maxSampleOffset: .zero
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragp = value.location
                            }
                            .onEnded { value in
                                withAnimation(.spring(.bouncy)) {
                                    dragp = CGPoint(x: cardsize.width / 2, y: cardsize.height / 2)
                                }
                            }
                    )
                    .rotation3DEffect(rotationAngleX, axis: (x: 0, y: 1, z: 0))
                    .rotation3DEffect(rotationAngleY, axis: (x: 1, y: 0, z: 0))
                }

                Spacer()

                VStack(spacing: 8) {
                    HStack {
                        Text("x: \(dragp.x, specifier: "%.0f")")
                        Spacer()
                        Text("y: \(dragp.y, specifier: "%.0f")")
                    }
                    .foregroundStyle(.white)
                    .font(.system(size: 13, design: .monospaced))

                    HStack {
                        Text("Radius: \(progress, specifier: "%.2f")")
                            .foregroundStyle(.white)
                            .font(.system(size: 13, design: .monospaced))
                        Slider(value: $progress, in: 0...1, step: 0.01)
                            .tint(.white)
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
    LightCardDemoView()
}
