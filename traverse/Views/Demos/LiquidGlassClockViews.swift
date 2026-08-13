//
//  LiquidGlassClockViews.swift
//  traverse
//
//  1:1 reproduction of radiofun/LiquidGlassClock
//

import SwiftUI
import Combine

// MARK: - Digit Views

struct NumberZero: View {
    var body: some View {
        ZStack { }
            .frame(width: 100, height: 120)
            .glassEffect(.clear.tint(.black.opacity(0.1)), in: .ellipse)
    }
}

struct NumberOne: View {
    var body: some View {
        VStack {
            ZStack { }
                .frame(width: 40, height: 40)
                .glassEffect(.clear.tint(.black.opacity(0.1)))
            Spacer()
        }
        ZStack { }
            .frame(width: 50, height: 120)
            .glassEffect(.clear.tint(.black.opacity(0.1)))
    }
}

struct NumberTwo: View {
    var body: some View {
        VStack {
            HStack {
                ZStack { }
                    .frame(width: 40, height: 40)
                    .glassEffect(.clear.tint(.black.opacity(0.1)))
                    .offset(y: -10)
                ZStack { }
                    .frame(width: 60, height: 70)
                    .glassEffect(.clear.tint(.black.opacity(0.1)), in: .rect(topLeadingCorner: .fixed(16), topTrailingCorner: .fixed(99), bottomLeadingCorner: .fixed(16), bottomTrailingCorner: .fixed(99)))
            }
            ZStack { }
                .frame(width: 120, height: 40)
                .glassEffect(.clear.tint(.black.opacity(0.1)))
        }
    }
}

struct NumberThree: View {
    var body: some View {
        ZStack {
            HStack {
                VStack {
                    ZStack { }
                        .frame(width: 40, height: 40)
                        .glassEffect(.clear.tint(.black.opacity(0.1)))

                    Color.clear
                        .frame(width: 40, height: 26)
                    ZStack { }
                        .frame(width: 40, height: 40)
                        .glassEffect(.clear.tint(.black.opacity(0.1)))
                }

                GlassEffectContainer(spacing: 20) {
                    VStack(spacing: -20) {
                        ZStack { }
                            .frame(width: 50, height: 60)
                            .glassEffect(.clear.tint(.black.opacity(0.1)))

                        ZStack { }
                            .frame(width: 40, height: 40)
                            .glassEffect(.clear.tint(.black.opacity(0.1)))
                            .offset(x: -20)

                        ZStack { }
                            .frame(width: 50, height: 60)
                            .glassEffect(.clear.tint(.black.opacity(0.1)))
                    }
                }
            }
        }
    }
}

struct NumberFour: View {
    var body: some View {
        ZStack {
            HStack {
                Color.clear
                    .frame(width: 24)

                ZStack { }
                    .frame(width: 40, height: 120)
                    .glassEffect(.clear.tint(.black.opacity(0.1)), in: .rect(cornerRadius: 99).rotation(Angle(degrees: 20)))
                    .offset(x: 4)

                VStack {
                    Spacer()

                    ZStack { }
                        .frame(width: 40, height: 60)
                        .glassEffect(.clear.tint(.black.opacity(0.1)))
                        .offset(y: 16)
                }
            }
        }
    }
}

struct NumberFive: View {
    var body: some View {
        HStack {
            VStack {
                ZStack { }
                    .frame(width: 40, height: 80)
                    .glassEffect(.clear.tint(.black.opacity(0.1)))
                ZStack { }
                    .frame(width: 40, height: 40)
                    .glassEffect(.clear.tint(.black.opacity(0.1)))
            }
            VStack(alignment: .leading) {
                ZStack { }
                    .frame(width: 50, height: 40)
                    .glassEffect(.clear.tint(.black.opacity(0.1)), in: .rect(topLeadingCorner: .fixed(20), topTrailingCorner: .fixed(20), bottomLeadingCorner: .fixed(20), bottomTrailingCorner: .fixed(20)))
                ZStack { }
                    .frame(width: 60, height: 80)
                    .glassEffect(.clear.tint(.black.opacity(0.1)), in: .rect(topLeadingCorner: .fixed(12), topTrailingCorner: .fixed(99), bottomLeadingCorner: .fixed(12), bottomTrailingCorner: .fixed(99)))
            }
        }
    }
}

struct NumberSix: View {
    var body: some View {
        HStack {
            ZStack { }
                .frame(width: 50, height: 120)
                .glassEffect(.clear.tint(.black.opacity(0.1)), in: .containerRelative)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 160,
                    bottomLeadingRadius: 160,
                    bottomTrailingRadius: 4,
                    topTrailingRadius: 4
                ))

            VStack(alignment: .leading) {
                ZStack { }
                    .frame(width: 40, height: 40)
                    .glassEffect(.clear.tint(.black.opacity(0.1)))

                ZStack { }
                    .frame(width: 60, height: 80)
                    .glassEffect(.clear.tint(.black.opacity(0.1)), in: .containerRelative)
                    .clipShape(UnevenRoundedRectangle(
                        topLeadingRadius: 12,
                        bottomLeadingRadius: 12,
                        bottomTrailingRadius: 180,
                        topTrailingRadius: 40
                    ))
            }
        }
    }
}

struct NumberSeven: View {
    var body: some View {
        ZStack {
            HStack {
                VStack {
                    ZStack { }
                        .frame(width: 50, height: 40)
                        .glassEffect(.clear.tint(.black.opacity(0.1)))
                    Spacer()
                }
                ZStack { }
                    .frame(width: 40, height: 130)
                    .glassEffect(.clear.tint(.black.opacity(0.1)), in: .rect(cornerRadius: 99).rotation(Angle(degrees: 20)))
                    .offset(x: -9, y: 10)
            }
        }
    }
}

struct NumberEight: View {
    var body: some View {
        HStack {
            GlassEffectContainer(spacing: 0) {
                VStack(spacing: -10) {
                    ZStack { }
                        .frame(width: 50, height: 70)
                        .glassEffect(.clear.tint(.black.opacity(0.1)), in: .rect(topLeadingCorner: .fixed(99), topTrailingCorner: .fixed(14), bottomLeadingCorner: .fixed(99), bottomTrailingCorner: .fixed(0)))
                    ZStack { }
                        .frame(width: 50, height: 70)
                        .glassEffect(.clear.tint(.black.opacity(0.1)), in: .rect(topLeadingCorner: .fixed(99), topTrailingCorner: .fixed(0), bottomLeadingCorner: .fixed(99), bottomTrailingCorner: .fixed(14)))
                }
            }

            GlassEffectContainer(spacing: 0) {
                VStack(spacing: -10) {
                    ZStack { }
                        .frame(width: 50, height: 70)
                        .glassEffect(.clear.tint(.black.opacity(0.1)), in: .rect(topLeadingCorner: .fixed(14), topTrailingCorner: .fixed(99), bottomLeadingCorner: .fixed(0), bottomTrailingCorner: .fixed(99)))
                    ZStack { }
                        .frame(width: 50, height: 70)
                        .glassEffect(.clear.tint(.black.opacity(0.1)), in: .rect(topLeadingCorner: .fixed(14), topTrailingCorner: .fixed(99), bottomLeadingCorner: .fixed(14), bottomTrailingCorner: .fixed(99)))
                }
            }
        }
    }
}

struct NumberNine: View {
    var body: some View {
        HStack {
            VStack {
                ZStack { }
                    .frame(width: 50, height: 70)
                    .glassEffect(.clear.tint(.black.opacity(0.1)), in: .containerRelative)
                    .clipShape(UnevenRoundedRectangle(
                        topLeadingRadius: 99,
                        bottomLeadingRadius: 99,
                        bottomTrailingRadius: 16,
                        topTrailingRadius: 16
                    ))
                ZStack { }
                    .frame(width: 40, height: 40)
                    .glassEffect(.clear.tint(.black.opacity(0.1)))
            }

            ZStack { }
                .frame(width: 50, height: 120)
                .glassEffect(.clear.tint(.black.opacity(0.1)), in: .containerRelative)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 12,
                    bottomLeadingRadius: 12,
                    bottomTrailingRadius: 99,
                    topTrailingRadius: 99
                ))
        }
    }
}

// MARK: - Main Liquid Glass Clock Demo View

struct LiquidGlassClockDemoView: View {
    @State private var time: CGFloat = 0
    @State private var currentTime = Date()
    @State private var timeOffset: Double = 0

    let timer = Timer.publish(every: 1/120, on: .main, in: .common).autoconnect()
    let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var adjustedTime: Date {
        currentTime.addingTimeInterval(timeOffset * 60)
    }

    var hourTens: Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH"
        let hour = Int(formatter.string(from: adjustedTime)) ?? 0
        return hour / 10
    }

    var hourOnes: Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH"
        let hour = Int(formatter.string(from: adjustedTime)) ?? 0
        return hour % 10
    }

    var minuteTens: Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "mm"
        let minute = Int(formatter.string(from: adjustedTime)) ?? 0
        return minute / 10
    }

    var minuteOnes: Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "mm"
        let minute = Int(formatter.string(from: adjustedTime)) ?? 0
        return minute % 10
    }

    @ViewBuilder
    func numberView(for digit: Int) -> some View {
        switch digit {
        case 0: NumberZero()
        case 1: NumberOne()
        case 2: NumberTwo()
        case 3: NumberThree()
        case 4: NumberFour()
        case 5: NumberFive()
        case 6: NumberSix()
        case 7: NumberSeven()
        case 8: NumberEight()
        case 9: NumberNine()
        default: NumberZero()
        }
    }

    var body: some View {
        ZStack {
            Color.red
                .ignoresSafeArea()

            Color.black.opacity(0.3)
                .ignoresSafeArea()

            // Clock
            VStack(spacing: 40) {
                HStack(spacing: 8) {
                    numberView(for: hourTens)
                    numberView(for: hourOnes)
                }
                .frame(height: 120)

                HStack(spacing: 8) {
                    numberView(for: minuteTens)
                    numberView(for: minuteOnes)
                }
                .frame(height: 120)
            }

            VStack(spacing: 20) {
                Spacer()
                HStack {
                    Text("+\(Int(timeOffset)) min")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .monospacedDigit()
                    Slider(value: $timeOffset, in: 0...60, step: 1)
                        .frame(width: 300)
                        .accentColor(.white)
                }
                .padding(.bottom, 24)
            }
            .tint(.yellow)
        }
        .onReceive(timer) { _ in
            time += 0.003
        }
        .onReceive(clockTimer) { _ in
            currentTime = Date()
        }
    }
}

#Preview {
    LiquidGlassClockDemoView()
}
