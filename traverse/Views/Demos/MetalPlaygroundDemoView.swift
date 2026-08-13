//
//  MetalPlaygroundDemoView.swift
//  traverse
//
//  1:1 implementation of https://github.com/radiofun/MetalPlayground
//

import SwiftUI

enum PlaygroundTab: String, CaseIterable, Identifiable {
    case wave = "Wave"
    case colorFilter = "Filter"
    case distortion = "Distort"
    case zoom = "Zoom"
    case ripple = "Ripple"

    var id: String { rawValue }
}

struct MetalPlaygroundDemoView: View {
    @State private var selectedTab: PlaygroundTab = .wave
    @State private var progress: Double = 0.5
    @State private var dragPosition: CGPoint = CGPoint(x: 170, y: 170)
    @State private var startDate = Date()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Picker("Playground", selection: $selectedTab) {
                    ForEach(PlaygroundTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Spacer()

                ZStack {
                    LinearGradient(
                        colors: [.indigo, .purple, .pink, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 40))
                                .foregroundStyle(.white)
                            Text(selectedTab.rawValue.uppercased())
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                    )
                    .frame(width: 340, height: 340)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .modifier(PlaygroundShaderModifier(tab: selectedTab, progress: progress, dragPosition: dragPosition, startDate: startDate))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragPosition = value.location
                            }
                    )
                }

                Spacer()

                VStack(spacing: 10) {
                    Text("Progress: \(progress, specifier: "%.2f")")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.white)

                    Slider(value: $progress, in: 0...1)
                        .tint(.white)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .padding()
            }
        }
    }
}

private struct PlaygroundShaderModifier: ViewModifier {
    let tab: PlaygroundTab
    let progress: Double
    let dragPosition: CGPoint
    let startDate: Date

    func body(content: Content) -> some View {
        switch tab {
        case .wave:
            content.layerEffect(
                ShaderLibrary.wave(
                    .float(progress * 10.0)
                ),
                maxSampleOffset: .zero
            )
        case .colorFilter:
            content.colorEffect(
                ShaderLibrary.colorfilter(
                    .float(progress)
                )
            )
        case .distortion:
            content.layerEffect(
                ShaderLibrary.distortion(
                    .float(progress),
                    .boundingRect
                ),
                maxSampleOffset: .zero
            )
        case .zoom:
            content.layerEffect(
                ShaderLibrary.zoom(
                    .boundingRect,
                    .float2(dragPosition),
                    .float(progress > 0.5 ? 1.0 : 0.0)
                ),
                maxSampleOffset: .zero
            )
        case .ripple:
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSince(startDate)
                content.layerEffect(
                    ShaderLibrary.Ripple(
                        .float2(dragPosition),
                        .float(time),
                        .float(progress * 40.0), // amplitude
                        .float(15.0),            // frequency
                        .float(4.0),             // decay
                        .float(1200.0)           // speed
                    ),
                    maxSampleOffset: CGSize(width: 100, height: 100)
                )
            }
        }
    }
}

#Preview {
    MetalPlaygroundDemoView()
}
