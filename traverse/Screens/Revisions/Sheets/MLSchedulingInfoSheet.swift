import SwiftUI

struct MLSchedulingInfoSheet: View {
    @StateObject private var paletteManager = ColorPaletteManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showTechnicalDetails = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Hero Section
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 44))
                            .foregroundStyle(paletteManager.selectedPalette.primary)
                        
                        Text("FSRS-5 Spaced Repetition")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Power-Law Forgetting Curve Scheduling")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .listRowBackground(Color.clear)
                
                // What is this section
                Section {
                    // NOTE: this used to say "ML-powered". It is not ML — FSRS-5 is a
                    // deterministic power-law forgetting curve. What AI contributes is one
                    // input to the quality score (the cognitive recall score) plus tier-based
                    // damping of stability growth, and only for premium accounts.
                    Text("This is a spaced repetition system based on FSRS-5 (Free Spaced Repetition Scheduler). Instead of static intervals (1d, 3d, 7d...), the algorithm tracks item-level Memory Stability (S) and Difficulty (D) to schedule reviews right when your retrievability reaches 85%.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text("Target Recall: 85% (R = 0.85)")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                        Text("— optimal spacing window")
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
                
                // Technical Details Section
                Section {
                    DisclosureGroup(isExpanded: $showTechnicalDetails) {
                        VStack(alignment: .leading, spacing: 10) {
                            TechRow(label: "Algorithm", value: "FSRS-5 (Free Spaced Repetition)")
                            TechRow(label: "Curve Model", value: "Power-Law Forgetting")
                            TechRow(label: "Key States", value: "Stability (S) & Difficulty (D)")
                            TechRow(label: "Target Recall", value: "85% Retrievability (R = 0.85)")
                            TechRow(label: "Clustering Prevention", value: "±10% Dynamic Interval Fuzzing")
                            
                            Divider()
                            
                            Text("Power-Law Forgetting Curve")
                                .font(.caption)
                                .fontWeight(.semibold)
                            
                            Text("R(t, S) = (1 + 19/81 * (t / S))^(-0.5)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(paletteManager.selectedPalette.primary)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            
                            Text("Retrievability R(t, S) represents recall probability after t days. At t = S, recall probability is exactly 90%.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Divider()
                            
                            Text("Stability Recall Growth")
                                .font(.caption)
                                .fontWeight(.semibold)
                            
                            Text("S' = S * e^(w8) * (11 - D) * S^(-w9) * (e^(w10*(1-R)) - 1)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(paletteManager.selectedPalette.primary)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            
                            Text("Successful recall expands stability S according to the spacing effect, while lapse/failure resets stability.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Divider()
                            
                            Text("Next Review Interval")
                                .font(.caption)
                                .fontWeight(.semibold)
                            
                            // The interval is not ≈ S: it equals S only at R = 0.9, the FSRS
                            // fixed point. At the scheduler's actual target of R = 0.85 the
                            // multiplier is (0.85^-2 - 1) / (19/81) ≈ 1.64.
                            Text("I = (S / (19/81)) * (0.85^(-2) - 1) ≈ 1.64 S")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(paletteManager.selectedPalette.primary)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            
                            Text("Reviews are scheduled right before memory retrievability drops below 85%, preventing item decay.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    } label: {
                        Label("Under the hood", systemImage: "cpu")
                    }
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

// MARK: - Tech Row
struct TechRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
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
