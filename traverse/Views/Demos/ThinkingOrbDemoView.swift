//
//  ThinkingOrbDemoView.swift
//  traverse
//
//  1:1 implementation of https://github.com/radiofun/thinkingorb
//

import SwiftUI
import Combine

struct ThinkingOrbDemoView: View {
    @State private var phase: CGFloat = 0
    @State private var progress: CGFloat = 0.5
    
    let timer = Timer.publish(every: 0.01, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.indigo.mix(with: .black, by: 0.8)
                .ignoresSafeArea()

            ZStack {
                RoundedRectangle(cornerRadius: 240)
                    .foregroundStyle(.blue)
                    .frame(width: 160, height: 160)
                    .blur(radius: 30)
                    .rotationEffect(Angle(radians: progress * 40))

                RoundedRectangle(cornerRadius: 240)
                    .foregroundStyle(.white)
                    .frame(width: 100, height: 60)
                    .blur(radius: 30)
                    .rotationEffect(Angle(radians: -progress * 40))

                RoundedRectangle(cornerRadius: 240)
                    .foregroundStyle(.white)
                    .frame(width: 120, height: 60)
                    .offset(y: -20)
                    .blur(radius: 40)
                    .rotationEffect(Angle(radians: progress * 20))
            }

            Text("What's on your mind?")
                .foregroundStyle(.white)
                .offset(y: 160)
                .bold()
        }
        .onReceive(timer) { _ in
            phase += 0.0005
            progress = sin(phase)
        }
    }
}

#Preview {
    ThinkingOrbDemoView()
}
