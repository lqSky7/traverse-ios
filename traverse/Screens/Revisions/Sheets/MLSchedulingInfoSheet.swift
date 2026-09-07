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
                    Text("This is an ML-powered spaced repetition system based on FSRS-5 (Free Spaced Repetition Scheduler). Instead of static intervals (1d, 3d, 7d...), the algorithm tracks item-level Memory Stability (S) and Difficulty (D) to schedule reviews right when your retrievability reaches 90%.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text("Target Recall: 90% (R = 0.9)")
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
                Section {
                    FeatureListRow(icon: "clock", text: "Time Spent Ratio (28%)", detail: "Ratio vs your personal median time per difficulty", iconColor: paletteManager.selectedPalette.primary)
                    FeatureListRow(icon: "gauge.medium", text: "Problem Difficulty (18%)", detail: "Intrinsic problem baseline (Easy / Medium / Hard)", iconColor: paletteManager.selectedPalette.primary)
                    FeatureListRow(icon: "exclamationmark.triangle", text: "Mistake Tags (18%)", detail: "Penalties for approach, TLE, syntax, or DS errors", iconColor: paletteManager.selectedPalette.primary)
                    FeatureListRow(icon: "arrow.counterclockwise", text: "Number of Retries (15%)", detail: "Softly scaled runs (typos & code runs non-punitive)", iconColor: paletteManager.selectedPalette.primary)
                    FeatureListRow(icon: "calendar.badge.clock", text: "Spacing Bonus (13%)", detail: "Logarithmic reward for long-gap successful recall", iconColor: paletteManager.selectedPalette.primary)
                    FeatureListRow(icon: "number", text: "Attempt Number (8%)", detail: "Review iteration expectation adjustment", iconColor: paletteManager.selectedPalette.primary)
                } header: {
                    Label("6 Quality Signals We Track", systemImage: "chart.line.uptrend.xyaxis")
                } footer: {
                    Text("Signals compute a Quality Score (q ∈ [0, 1]) mapped to FSRS grades (Again, Hard, Good, Easy) to scale stability.")
                }
                
                // Technical Details Section
                Section {
                    DisclosureGroup(isExpanded: $showTechnicalDetails) {
                        VStack(alignment: .leading, spacing: 10) {
                            TechRow(label: "Algorithm", value: "FSRS-5 (Free Spaced Repetition)")
                            TechRow(label: "Curve Model", value: "Power-Law Forgetting")
                            TechRow(label: "Key States", value: "Stability (S) & Difficulty (D)")
                            TechRow(label: "Target Recall", value: "90% Retrievability (R = 0.9)")
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
                            
                            Text("I = (S / (19/81)) * (0.9^(-2) - 1) ≈ S")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(paletteManager.selectedPalette.primary)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            
                            Text("Reviews are scheduled right before memory retrievability drops below 90%, preventing item decay.")
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
