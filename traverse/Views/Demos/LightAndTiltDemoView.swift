//
//  LightAndTiltDemoView.swift
//  traverse
//
//  1:1 implementation of https://github.com/radiofun/LightandTilt
//

import SwiftUI
import CoreMotion

struct LightAndTiltDemoView: View {
    @State private var a: CGFloat = 0.57
    @State private var b: CGFloat = 3.8
    @State private var dragp: CGPoint = CGPoint(x: 170, y: 170)
    @State private var tilt: CGPoint = .zero
    @State private var isTilt: Bool = false
    
    private let motionManager = CMMotionManager()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                Spacer()

                ZStack {
                    LinearGradient(colors: [.red, .blue], startPoint: .leading, endPoint: .trailing)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: isTilt ? "iphone.radiowaves.left.and.right" : "hand.draw")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.white)
                                Text("LIGHT & TILT")
                                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                            }
                        )
                        .blur(radius: 20)
                        .layerEffect(
                            ShaderLibrary.shine(
                                .boundingRect,
                                .float2(isTilt ? tilt : dragp),
                                .float(a),
                                .float(b)
                            ),
                            maxSampleOffset: .zero
                        )
                }
                .frame(width: 340, height: 340)
                .cornerRadius(32)
                .shadow(radius: 20)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragp = value.location
                        }
                )
                
                Spacer()
                
                VStack(spacing: 12) {
                    Toggle("Use Device Motion Tilt?", isOn: $isTilt)
                        .foregroundStyle(.white)

                    HStack {
                        Text("a: \(a, specifier: "%.3f")")
                            .frame(width: 80, alignment: .leading)
                        Slider(value: $a, in: 0...1)
                    }
                    HStack {
                        Text("b: \(b, specifier: "%.3f")")
                            .frame(width: 80, alignment: .leading)
                        Slider(value: $b, in: 0...1)
                    }
                }
                .tint(.white)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white)
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .padding()
            }
        }
        .onAppear {
            if motionManager.isDeviceMotionAvailable {
                motionManager.startDeviceMotionUpdates(to: .main) { motion, error in
                    guard let motion = motion else { return }
                    let x = motion.attitude.roll
                    let y = motion.attitude.pitch
                    tilt = CGPoint(x: 170 + CGFloat(x) * 400, y: 170 + CGFloat(y) * 400)
                }
            }
        }
        .onDisappear {
            motionManager.stopDeviceMotionUpdates()
        }
    }
}

#Preview {
    LightAndTiltDemoView()
}
