//
//  SlowRippleDemoView.swift
//  traverse
//
//  1:1 implementation of https://github.com/radiofun/slowripple
//

import SwiftUI
import Combine

struct SlowRippleDemoView: View {
    @State private var time: CGFloat = 0.1
    @State private var noise: CGFloat = 4
    @State private var strength: CGFloat = 1
    @State private var dragp: CGPoint = .zero
    @State private var angle: CGFloat = 0

    private let timer = Timer.publish(every: 1/120, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 30) {
                ZStack {
                    ZStack {
                        LinearGradient(colors: [.brown.mix(with: .black, by: 0.8), .orange, .white], startPoint: .top, endPoint: .bottomTrailing)
                            .frame(width: 340, height: 300)
                            .blur(radius: 20)
                            .layerEffect(
                                ShaderLibrary.fbp(
                                    .boundingRect,
                                    .float2(dragp),
                                    .float(time),
                                    .float(noise),
                                    .float(strength)
                                ),
                                maxSampleOffset: CGSize(width: 200, height: 200)
                            )

                        Color.black.opacity(0.3)
                        
                        VStack {
                            Spacer()
                            HStack {
                                Text("time: \(time, specifier: "%.2f") / ")
                                Text("noise: \(noise, specifier: "%.2f") / ")
                                Text("str: \(strength, specifier: "%.2f")")
                                Spacer()
                            }
                        }
                        .frame(width: 310, height: 260)
                        .foregroundStyle(.white)
                        .font(.system(size: 11, design: .monospaced))
                    }
                    .frame(width: 340, height: 300)
                    .cornerRadius(16)
                    .shadow(radius: 12)
                }

                VStack(spacing: 12) {
                    HStack {
                        Text("Time")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(width: 70, alignment: .leading)
                        Slider(value: $time, in: 0...1)
                            .tint(.white)
                    }
                    HStack {
                        Text("Noise")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(width: 70, alignment: .leading)
                        Slider(value: $noise, in: 0...8)
                            .tint(.white)
                    }
                    HStack {
                        Text("Strength")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(width: 70, alignment: .leading)
                        Slider(value: $strength, in: 0...10)
                            .tint(.white)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .padding(.horizontal)
            }
        }
        .onReceive(timer) { _ in
            angle += 0.001
            dragp = CGPoint(
                x: 5 + cos(angle) * 300,
                y: 5 + sin(angle) * 300
            )
        }
    }
}

#Preview {
    SlowRippleDemoView()
}
