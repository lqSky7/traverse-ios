//
//  IntelligenceSummaryCard.swift
//  traverse
//

import SwiftUI

@available(iOS 18.2, *)
struct IntelligenceSummaryCard: View {
    let streak: Int
    let solvedToday: Bool
    let totalSolves: Int
    let recentSolves: [Solve]
    let difficulty: ProblemsByDifficulty
    @ObservedObject var paletteManager: ColorPaletteManager
    
    @StateObject private var manager = IntelligenceManager.shared
    @State private var isExpanded = false
    @State private var showGlow = false
    @State private var messageOpacity: Double = 0
    @State private var messageBlur: CGFloat = 10
    
    private var isGenerating: Bool {
        if case .generating = manager.state { return true }
        return false
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(paletteManager.color(at: 3))
                    
                    Text("Intelligence")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                generateButton
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // Content
            contentView
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .overlay(
            Group {
                if showGlow {
                    RoundedRectangle(cornerRadius: 16)
                        .intelligenceStroke(
                            lineWidths: [2, 3, 4, 5],
                            blurs: [0, 2, 6, 8]
                        )
                        .transition(.opacity)
                }
            }
        )
        .onReceive(manager.$state) { newState in
            withAnimation(.easeInOut(duration: 0.3)) {
                if case .generating = newState {
                    showGlow = true
                    messageOpacity = 0
                    messageBlur = 10
                } else {
                    showGlow = false
                }
            }
            
            // Apple-like text reveal animation
            if case .ready = newState {
                withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                    messageOpacity = 1
                    messageBlur = 0
                }
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch manager.state {
        case .idle:
            VStack(spacing: 12) {
                Text("Get personalized insights")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("Tap the button above to receive AI-powered advice based on your coding journey")
                    .font(.caption)
                    .foregroundStyle(.secondary.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            
        case .generating:
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(Color(red: 141/255, green: 159/255, blue: 255/255))
                    
                    Text("Analyzing your progress...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Shimmer effect for loading
                VStack(alignment: .leading, spacing: 8) {
                    ShimmerLine(width: .infinity)
                    ShimmerLine(width: 280)
                    ShimmerLine(width: 320)
                }
            }
            .padding(.vertical, 8)
            
        case .ready(let summary):
            VStack(alignment: .leading, spacing: 12) {
                Text(summary.message)
                    .font(.body)
                    .foregroundStyle(.white)
                    .lineSpacing(4)
                    .opacity(messageOpacity)
                    .blur(radius: messageBlur)
                
                HStack {
                    Text("Generated \(timeAgo(from: summary.generatedAt))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button {
                        Task {
                            await manager.generateSummary(
                                streak: streak,
                                solvedToday: solvedToday,
                                totalSolves: totalSolves,
                                recentSolves: recentSolves,
                                difficulty: difficulty
                            )
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption2)
                            Text("Refresh")
                                .font(.caption2)
                        }
                        .foregroundStyle(paletteManager.color(at: 3))
                    }
                }
                .padding(.top, 4)
                .opacity(messageOpacity)
            }
            .padding(.vertical, 8)
            
        case .error(let message):
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Button {
                    Task {
                        await manager.generateSummary(
                            streak: streak,
                            solvedToday: solvedToday,
                            totalSolves: totalSolves,
                            recentSolves: recentSolves,
                            difficulty: difficulty
                        )
                    }
                } label: {
                    Text("Try Again")
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 141/255, green: 159/255, blue: 255/255))
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    @ViewBuilder
    private var generateButton: some View {
        Button {
            Task {
                await manager.generateSummary(
                    streak: streak,
                    solvedToday: solvedToday,
                    totalSolves: totalSolves,
                    recentSolves: recentSolves,
                    difficulty: difficulty
                )
            }
        } label: {
            HStack(spacing: 6) {
                if case .generating = manager.state {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 14, weight: .semibold))
                }
                
                Text(buttonText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(paletteManager.color(at: 3))
            )
            .scaleEffect({ if case .generating = manager.state { return 0.95 } else { return 1.0 } }())
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isGenerating)
        }
        .disabled({ if case .generating = manager.state { true } else { false } }())
    }
    
    private var buttonText: String {
        switch manager.state {
        case .idle:
            return "Generate"
        case .generating:
            return "Generating"
        case .ready:
            return "Regenerate"
        case .error:
            return "Generate"
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        
        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours)h ago"
        } else {
            let days = seconds / 86400
            return "\(days)d ago"
        }
    }
}

// MARK: - Shimmer Loading Effect

private struct ShimmerLine: View {
    let width: CGFloat?
    @State private var phase: CGFloat = 0
    
    init(width: CGFloat?) {
        self.width = width
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.05),
                        Color.white.opacity(0.15),
                        Color.white.opacity(0.05)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: 12)
            .mask(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: phase)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 400
                }
            }
    }
}

// Fallback view for iOS < 18.2
struct IntelligenceSummaryCardFallback: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                
                Text("Intelligence")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            
            Text("Apple Intelligence requires iOS 18.2 or later")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemGray6).opacity(0.3))
        )
    }
}

#Preview {
    if #available(iOS 18.2, *) {
        let difficulty = try! JSONDecoder().decode(
            ProblemsByDifficulty.self,
            from: """
            {"easy": 20, "medium": 20, "hard": 5}
            """.data(using: .utf8)!
        )
        
        IntelligenceSummaryCard(
            streak: 7,
            solvedToday: true,
            totalSolves: 45,
            recentSolves: [],
            difficulty: difficulty,
            paletteManager: ColorPaletteManager.shared
        )
        .padding()
        .background(Color.black)
    } else {
        IntelligenceSummaryCardFallback()
            .padding()
            .background(Color.black)
    }
}

