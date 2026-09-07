import SwiftUI

struct RevisionScoreExplanationSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tracks your overall revision consistency and memory retention health over the past 7 days.\n\n• Memory Retention: Measures how effectively your review habit reinforces learned DSA concepts to maintain strong long-term recall.\n\n• Outcome-Independent: Focuses purely on engagement and recall effort — it is not penalized when you struggle on difficult problems.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(20)
            .navigationTitle("Revision Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarScrollMinimization()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Lighting Sun Background (Lighting Simulation Shader from Settings > Demo)
