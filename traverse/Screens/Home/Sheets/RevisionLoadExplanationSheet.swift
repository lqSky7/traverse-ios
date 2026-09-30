import SwiftUI

/// Explains the Revision Load figure. Reached from the info button on the load
/// detail screen, in the same slot Apple uses for its training-load explainer.
struct RevisionLoadExplanationSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Compares how much revision work you did in the last 7 days against your own 28-day baseline. It is a relative measure — it only ever compares you to you.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    explainer(
                        title: "Load",
                        body: "Every completed revision counts, and every problem you work on counts. Harder problems count for more than easier ones, the same way a longer workout counts for more training load."
                    )

                    explainer(
                        title: "7-Day vs. 28-Day",
                        body: "Your daily average over the last 7 days is measured against your daily average over the last 28. Staying between 80% and 130% of baseline is the sweet spot — enough to keep memory strong, not so much that you burn out."
                    )

                    explainer(
                        title: "Bands",
                        body: "Well Below and Below mean you are tapering and retention will start to slip. Optimal means you are holding steady. Above and Well Above mean a sharp ramp — expect gains, but take a lighter day if the workload becomes hard to sustain."
                    )

                    explainer(
                        title: "Revision Score",
                        body: "The score in the footer is separate: it tracks revision consistency and memory retention over the past 7 days, and is never penalised for struggling on hard problems."
                    )
                }
                .padding(20)
            }
            .navigationTitle("Revision Load")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarScrollMinimization()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func explainer(title: String, body text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    RevisionLoadExplanationSheet()
        .preferredColorScheme(.dark)
}
