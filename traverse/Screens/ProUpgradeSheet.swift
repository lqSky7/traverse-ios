//
//  ProUpgradeSheet.swift
//  traverse
//

import SwiftUI
import AVKit
import Combine

struct ProUpgradeSheet: View {
    @Environment(\.openURL) private var openURL
    
    private let features: [(icon: String, text: String)] = [
        ("brain.head.profile", "ML Revision"),
        ("rectangle.grid.2x2.fill", "All Platforms"),
        ("bolt.fill", "Early Access"),
        ("applewatch", "WatchOS"),
        ("arrow.triangle.2.circlepath", "Anki Sync"),
        ("chart.line.uptrend.xyaxis", "AI Insights")
    ]
    
    var body: some View {
        ZStack {
            // Video background
            LoopingVideoBackground()
                .ignoresSafeArea()
            
            // Dark overlay for better text legibility
            Color.black.opacity(0.1)
                .ignoresSafeArea()
            
            // Content - all centered
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 20)
                
                // Support development message
                Text("Subscription supports ongoing development")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.vertical)
                
                // Header with pricing
                VStack(spacing: 8) {
                    Text("Premium")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("₹49")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(.white)
                        Text("/mo")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                
                // Features as centered chips
                FlowLayoutCentered(spacing: 10) {
                    ForEach(features, id: \.text) { feature in
                        FeatureChip(icon: feature.icon, text: feature.text)
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Subscribe button with liquid glass
                SubscribeButton(action: openPaymentPage)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
    }
    
    private func openPaymentPage() {
        if let url = URL(string: "https://leet-feedback.vercel.app/") {
            openURL(url)
        }
    }
}

// MARK: - Feature Chip
struct FeatureChip: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.footnote)
            Text(text)
                .font(.footnote)
                .fontWeight(.medium)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .modifier(LiquidGlassChipModifier())
    }
}

// MARK: - Liquid Glass Chip Modifier
struct LiquidGlassChipModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.clear.interactive(), in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

// MARK: - Subscribe Button
struct SubscribeButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("Subscribe Now")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
        }
        .modifier(LiquidGlassSubscribeButton())
    }
}

// MARK: - Liquid Glass Subscribe Button Modifier
struct LiquidGlassSubscribeButton: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.clear.interactive(), in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

// MARK: - Centered Flow Layout for Chips
struct FlowLayoutCentered: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, placement) in result.placements.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + placement.x, y: bounds.minY + placement.y),
                proposal: ProposedViewSize(placement.size)
            )
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, placements: [(x: CGFloat, y: CGFloat, size: CGSize)]) {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[(index: Int, size: CGSize)]] = []
        var currentRow: [(index: Int, size: CGSize)] = []
        var currentRowWidth: CGFloat = 0
        
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentRowWidth + size.width > maxWidth && !currentRow.isEmpty {
                rows.append(currentRow)
                currentRow = [(index, size)]
                currentRowWidth = size.width + spacing
            } else {
                currentRow.append((index, size))
                currentRowWidth += size.width + spacing
            }
        }
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        
        var placements: [(x: CGFloat, y: CGFloat, size: CGSize)] = Array(repeating: (0, 0, .zero), count: subviews.count)
        var currentY: CGFloat = 0
        
        for row in rows {
            let rowWidth = row.reduce(0) { $0 + $1.size.width } + CGFloat(max(0, row.count - 1)) * spacing
            let rowHeight = row.map { $0.size.height }.max() ?? 0
            let startX = (maxWidth - rowWidth) / 2
            
            var currentX = startX
            for item in row {
                placements[item.index] = (x: currentX, y: currentY, size: item.size)
                currentX += item.size.width + spacing
            }
            currentY += rowHeight + spacing
        }
        
        let totalHeight = currentY - spacing
        return (CGSize(width: maxWidth, height: max(0, totalHeight)), placements)
    }
}

// MARK: - Looping Video Background
struct LoopingVideoBackground: View {
    @StateObject private var playerManager = VideoPlayerManager()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                
                if let player = playerManager.player {
                    VideoPlayerView(player: player)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
        }
        .onAppear {
            playerManager.play()
        }
        .onDisappear {
            playerManager.pause()
        }
    }
}


class VideoPlayerManager: ObservableObject {
    @Published var player: AVPlayer?
    private var looper: AVPlayerLooper?
    
    init() {
        setupPlayer()
    }
    
    private func setupPlayer() {
        guard let url = Bundle.main.url(forResource: "loopbg", withExtension: "mp4") else {
            return
        }
        
        let playerItem = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(playerItem: playerItem)
        queuePlayer.isMuted = true
        
        looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
        player = queuePlayer
    }
    
    func play() {
        player?.play()
    }
    
    func pause() {
        player?.pause()
    }
}


struct VideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        controller.view.backgroundColor = .clear
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // No updates needed
    }
}


#Preview {
    ProUpgradeSheet()
}
