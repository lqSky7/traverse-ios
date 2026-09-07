//
//  LiquidGlassDemoView.swift
//  traverse
//
//  1:1 implementation of https://github.com/radiofun/MinsangMetalSample (Liquid Glass)
//

import SwiftUI
import Combine

struct LiquidGlassDemoView: View {
    @State private var strength: CGFloat = 26
    @State private var radius: CGFloat = 55
    @State private var cornerradii: CGFloat = 0.2
    @State private var refraction: CGFloat = 2.6
    @State private var size: CGFloat = 360
    @State private var dp = CGPoint(x: 320, y: 600)

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            ZStack {

                ZStack {
                    Color.yellow
                        .ignoresSafeArea()
                    VStack {
                        Text("Metal")
                            .font(.system(size: 140, design: .default))
                            .fontWeight(.semibold)
                        Text("0617 - Liquid Glass")
                            .font(.system(size: 14, design: .default))
                    }

                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dp = value.location

                        }
                )
                .layerEffect(ShaderLibrary.roundedGlass(
                    .boundingRect,
                    .float2(dp),
                    .float(radius),
                    .float(strength),
                    .float(cornerradii),
                    .float(refraction),
                    .float(size)), maxSampleOffset: CGSize(width: 200, height: 200))
                .onAppear {
                    withAnimation(.spring(.smooth)) {
                        dp = CGPoint(x: 320, y: 320)
                    }
                }

                VStack {
                    Spacer()
                    VStack {
                        Color.clear
                            .frame(height: 8)
                        HStack {
                            Text("Intensity : \(strength, specifier: "%.1f")")
                            Slider(value: $strength, in: 0...66)
                        }
                        HStack {
                            Text("Radius : \(radius, specifier: "%.1f")")
                            Slider(value: $radius, in: 0...60)
                        }
                        HStack {
                            Text("CA : \(cornerradii, specifier: "%.1f")")
                            Slider(value: $cornerradii, in: 0...44)
                        }

                        HStack {
                            Text("Border : \(refraction, specifier: "%.1f")")
                            Slider(value: $refraction, in: 0...12)
                        }

                    }
                    .frame(width: 320)
                    .font(.system(size: 14, design: .rounded))
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(radius: 10)

                }
                .tint(.black)
                .padding()

            }
        }
    }
}

// Alias for 1:1 symbol compatibility
typealias Jun17 = LiquidGlassDemoView

#Preview {
    LiquidGlassDemoView()
}
