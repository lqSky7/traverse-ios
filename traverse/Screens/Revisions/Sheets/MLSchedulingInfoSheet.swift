import SwiftUI

struct MLSchedulingInfoSheet: View {
    @StateObject private var paletteManager = ColorPaletteManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                // Hero Section
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 44))
                            .foregroundStyle(paletteManager.selectedPalette.primary)
                        
                        Text("Spaced Repetition")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Reviews timed for when you're about to forget")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .listRowBackground(Color.clear)
                
                // What is this section
                Section {
                    // NOTE: this used to say "ML-powered", and later explained the algorithm
                    // (FSRS-5, stability/difficulty, the 85% retrievability target). Scheduling
                    // internals are deliberately not surfaced to users — see the
                    // traverse-revision-scheduling skill. Keep this plain-language.
                    Text("Traverse follows how each problem goes for you and schedules the next revision for when you're about to forget it. Recall a problem well and the next review moves further out; struggle with it and it comes back sooner.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text("Adapts to you")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                        Text("— no fixed 1d / 3d / 7d ladder")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("What is this?", systemImage: "questionmark.circle.fill")
                }
                
                // Features Section
                // Deliberately qualitative — the factor weights are internal and are not shown
                // to users. They have drifted before (a sixth "Mistake Tags (18%)" row that was
                // never a real factor; the attempt weight listed as 8% when it is 4%), and a
                // percentage invites users to reconstruct the scoring function. Keep this list
                // descriptive, with no numbers.
                Section {
                    FeatureListRow(icon: "clock", text: "Time Spent Ratio", detail: "How your solve time compares with your personal median for that difficulty", iconColor: paletteManager.selectedPalette.primary)
                    FeatureListRow(icon: "gauge.medium", text: "Problem Difficulty", detail: "Intrinsic problem baseline (Easy / Medium / Hard)", iconColor: paletteManager.selectedPalette.primary)
                    FeatureListRow(icon: "arrow.counterclockwise", text: "Number of Retries", detail: "Softly scaled runs (typos & code runs non-punitive)", iconColor: paletteManager.selectedPalette.primary)
                    FeatureListRow(icon: "calendar.badge.clock", text: "Spacing", detail: "Rewards a successful recall after a longer gap", iconColor: paletteManager.selectedPalette.primary)
                    FeatureListRow(icon: "number", text: "Attempt Number", detail: "How many times you have revised this problem", iconColor: paletteManager.selectedPalette.primary)
                } header: {
                    Label("What Shapes Your Schedule", systemImage: "chart.line.uptrend.xyaxis")
                }
                
                // Got it Button
                Section {
                    Button(action: { dismiss() }) {
                        Text("Got it")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .tint(paletteManager.color(at: 2))
                    .buttonStyle(.borderedProminent)
                    .modifier(LiquidGlassCapsuleButton())
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
            }
            .navigationTitle("Smart Revisions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarScrollMinimization()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Feature List Row
struct FeatureListRow: View {
    let icon: String
    let text: String
    let detail: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.subheadline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// Helper view for info rows
struct InfoRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.body)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}

// MARK: - Easter Egg Helper
