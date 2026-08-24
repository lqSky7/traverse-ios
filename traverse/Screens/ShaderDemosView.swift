//
//  ShaderDemosView.swift
//  traverse
//
//  Settings gallery rendering all radiofun repositories 1:1.
//

import SwiftUI

enum ShaderDemoTab: String, CaseIterable, Identifiable {
    case ripplesdf = "Ripple SDF"
    case liquidGlassClock = "Liquid Clock"
    case bottomGradient = "Bottom Ambient"
    case flutedGlass = "Fluted Glass"
    case arcSelector = "Arc Selector"
    case thinkingOrb = "Thinking Orb"
    case metalWarp = "Metal Warp"
    case heroTransition = "Hero Transition"
    case gooeyBlobs = "Gooey Blobs"
    case slowRipple = "Slow Ripple"
    case lightingSim = "Lighting Sim"
    case gradientShader = "Gradient Shader"
    case metalPlayground = "Metal Playground"
    case lightAndTilt = "Light & Tilt"
    case lightCard = "Light Card"
    case domainWarping = "Voice Domain Warp"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .ripplesdf: return "water.waves"
        case .liquidGlassClock: return "clock.fill"
        case .bottomGradient: return "square.bottomhalf.filled"
        case .flutedGlass: return "square.split.3x3"
        case .arcSelector: return "circle.dashed"
        case .thinkingOrb: return "sparkles"
        case .metalWarp: return "hand.tap.fill"
        case .heroTransition: return "arrow.up.left.and.arrow.down.right"
        case .gooeyBlobs: return "drop.fill"
        case .slowRipple: return "wave.3.forward"
        case .lightingSim: return "sun.max.fill"
        case .gradientShader: return "paintpalette.fill"
        case .metalPlayground: return "slider.horizontal.3"
        case .lightAndTilt: return "iphone.radiowaves.left.and.right"
        case .lightCard: return "light.beacon.max"
        case .domainWarping: return "waveform"
        }
    }
}

struct ShaderDemosView: View {
    @State private var selectedTab: ShaderDemoTab = .flutedGlass
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                switch selectedTab {
                case .ripplesdf:
                    RippleSDFDemoView()
                case .liquidGlassClock:
                    LiquidGlassClockDemoView()
                case .bottomGradient:
                    BottomAmbientLightDemoView()
                case .flutedGlass:
                    FlutedGlassDemoView()
                case .arcSelector:
                    ArcSelectorDemoView()
                case .thinkingOrb:
                    ThinkingOrbDemoView()
                case .metalWarp:
                    MetalWarpDemoView()
                case .heroTransition:
                    HeroTransitionDemoView()
                case .gooeyBlobs:
                    GooeyBlobsDemoView()
                case .slowRipple:
                    SlowRippleDemoView()
                case .lightingSim:
                    LightingSimDemoView()
                case .gradientShader:
                    GradientShaderDemoView()
                case .metalPlayground:
                    MetalPlaygroundDemoView()
                case .lightAndTilt:
                    LightAndTiltDemoView()
                case .lightCard:
                    LightCardDemoView()
                case .domainWarping:
                    DomainWarpingDemoView()
                }
            }
            .navigationTitle("Shader & UI Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarScrollMinimization()
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Menu {
                        ForEach(ShaderDemoTab.allCases) { tab in
                            Button {
                                selectedTab = tab
                            } label: {
                                HStack {
                                    Label(tab.rawValue, systemImage: tab.icon)
                                    if selectedTab == tab {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(selectedTab.rawValue)
                                .font(.system(size: 15, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(20)
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

#Preview {
    ShaderDemosView()
}
