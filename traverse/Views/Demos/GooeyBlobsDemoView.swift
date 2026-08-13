//
//  GooeyBlobsDemoView.swift
//  traverse
//
//  1:1 implementation of https://github.com/radiofun/gooeyblobs
//

import SwiftUI

struct GooeyBlobsDemoView: View {
    @State private var offset: CGSize = .zero
    @State private var lastoffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                Spacer()

                Canvas { context, size in
                    let centerX = size.width / 2
                    let centerY = size.height / 2

                    context.addFilter(.alphaThreshold(min: 0.6, max: 1.0, color: .orange))
                    context.addFilter(.blur(radius: 20))

                    context.drawLayer { ctx in
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: centerX - 90, y: centerY - 90, width: 180, height: 180)),
                            with: .color(.black)
                        )

                        ctx.fill(
                            Path(roundedRect: CGRect(x: centerX + lastoffset.width + offset.width - 60, y: centerY + lastoffset.height + offset.height - 60, width: 120, height: 120), cornerRadius: 10),
                            with: .color(.black)
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 500)
                .gesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .local)
                        .onChanged { value in
                            offset = value.translation
                        }
                        .onEnded { value in
                            withAnimation(.smooth) {
                                lastoffset.width += offset.width
                                lastoffset.height += offset.height
                                offset = .zero
                            }
                        }
                )

                Spacer()

                Text("Drag small blob to merge with stationary center blob")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.gray)
                    .padding(.bottom, 20)
            }
        }
    }
}

#Preview {
    GooeyBlobsDemoView()
}
