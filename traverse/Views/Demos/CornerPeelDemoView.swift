//
//  CornerPeelDemoView.swift
//  traverse
//
//  1:1 implementation of https://github.com/radiofun/MinsangMetalSample (Corner Peel)
//

import SwiftUI

struct CornerPeelDemoView: View {
    @State private var progress: CGFloat = 0.3
    @State private var opacity: CGFloat = 0.63
    @State private var angle: CGFloat = 4.5
    @State private var lastp: CGPoint = .zero
    @State private var dragp: CGPoint = .zero

    var body: some View {
        ZStack {

            ZStack {

                Color.black
                    .frame(width: 360, height: 360)
                    .layerEffect(
                        ShaderLibrary.cornerPeel(
                            .boundingRect,
                            .float(progress),
                            .float(opacity),
                            .float(angle)
                        ),
                        maxSampleOffset: CGSize(width: 360, height: 360)
                    )

            }
            .frame(width: 360, height: 360)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragp.y = value.translation.height
                        // Project drag onto the peel direction, rotated by angle
                        let cosA = cos(angle)
                        let sinA = sin(angle)
                        let tx = value.translation.width
                        let ty = value.translation.height
                        let diag = (-(tx + ty) * cosA + (tx - ty) * sinA) * 0.5
                        progress = max(0, min(1, lastp.x + diag / 360))
                    }
                    .onEnded { value in
                        let cosA = cos(angle)
                        let sinA = sin(angle)
                        let tx = value.translation.width
                        let ty = value.translation.height
                        let diag = (-(tx + ty) * cosA + (tx - ty) * sinA) * 0.5
                        lastp.x = max(0, min(1, lastp.x + diag / 360))
                        dragp = .zero
                    }
            )
            .onAppear {
                lastp.x = progress
            }

            VStack(spacing: 24) {
                VStack {
                    Text("Drag to Roll, Change Angle with Slider")
                        .font(.system(size: 15))
                        .bold()
                    Text("Inspired by iOS Page Curl Animation")
                        .font(.caption)
                        .opacity(0.5)
                }
                Spacer()
                HStack {
                    Text("Opacity")
                    Slider(value: $opacity, in: 0...1)
                    Text("\(opacity, specifier: "%.2f")")
                        .monospacedDigit()
                }
                .font(.system(size: 15))
                HStack {
                    Text("Angle")
                    Slider(value: $angle, in: 0...5.5)
                    Text("\(angle, specifier: "%.2f")")
                        .monospacedDigit()

                }
                .font(.system(size: 15))

            }
            .foregroundStyle(.primary)
            .tint(.yellow)
            .padding()
        }
    }
}

// Alias for 1:1 symbol compatibility
typealias Feb21_Corner = CornerPeelDemoView

#Preview {
    CornerPeelDemoView()
}
