import SwiftUI

/// Customise the two ring goals.
///
/// Two numbers, both defaulting to 1, both clamped to the server's accepted
/// range. The ring preview at the top is live: it redraws as the steppers move,
/// against today's real counts, so the user can see whether the value they are
/// choosing would already be met today or would take the rest of the evening.
///
/// The save is explicit rather than per-tap. Two steppers that each fire a
/// request would send a burst of partial updates while the user is still
/// deciding, and the server's "a change applies from tomorrow" rule means the
/// intermediate values are not just noisy, they are wrong.
struct RingGoalsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var ringsManager = RingsManager.shared
    @ObservedObject private var paletteManager = ColorPaletteManager.shared

    @State private var solveGoal: Int = 1
    @State private var revisionGoal: Int = 1
    @State private var isSaving = false
    @State private var didLoadInitialValues = false

    private let range = RingGoals.minimum...RingGoals.maximum

    private var hasChanges: Bool {
        solveGoal != ringsManager.goals.solveGoal
            || revisionGoal != ringsManager.goals.revisionGoal
    }

    /// True when the chosen values differ from the goals today is being measured
    /// against. That is the case worth explaining, because the rings will not
    /// move until tomorrow.
    private var differsFromToday: Bool {
        solveGoal != ringsManager.progress.solveGoal
            || revisionGoal != ringsManager.progress.revisionGoal
    }

    private var solveColor: Color { paletteManager.color(at: 0) }
    private var revisionColor: Color { paletteManager.color(at: 1) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    preview

                    explanation

                    VStack(spacing: 14) {
                        goalRow(
                            title: "New solves",
                            subtitle: "Problems solved for the first time",
                            color: solveColor,
                            value: $solveGoal,
                            doneToday: ringsManager.progress.solves
                        )

                        goalRow(
                            title: "Revisions",
                            subtitle: "Scheduled reviews completed",
                            color: revisionColor,
                            value: $revisionGoal,
                            doneToday: ringsManager.progress.revisions
                        )
                    }

                    if let error = ringsManager.saveError {
                        errorBanner(error)
                    }

                    if differsFromToday && hasChanges {
                        tomorrowNote
                    }
                }
                .padding(20)
            }
            .background(Color.black)
            .navigationTitle("Your rings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Save").fontWeight(.semibold)
                        }
                    }
                    .disabled(!hasChanges || isSaving)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Seeded once, so a refresh arriving mid-edit cannot yank the
            // steppers out from under the user.
            guard !didLoadInitialValues else { return }
            didLoadInitialValues = true
            solveGoal = ringsManager.goals.solveGoal
            revisionGoal = ringsManager.goals.revisionGoal
        }
        .task {
            await ringsManager.refresh()
        }
    }

    // MARK: - Preview

    private var preview: some View {
        VStack(spacing: 16) {
            ActivityRingsView(
                solveFraction: previewFraction(ringsManager.progress.solves, solveGoal),
                revisionFraction: previewFraction(ringsManager.progress.revisions, revisionGoal),
                solveColor: solveColor,
                revisionColor: revisionColor,
                diameter: 132,
                strokeWidth: 14,
                ringGap: 5
            )
            .padding(.top, 4)

            Text(progressSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func previewFraction(_ count: Int, _ goal: Int) -> Double {
        guard goal > 0 else { return 0 }
        return min(Double(count) / Double(goal), 1)
    }

    private var progressSummary: String {
        let solvedMet = ringsManager.progress.solves >= solveGoal
        let revisedMet = ringsManager.progress.revisions >= revisionGoal

        switch (solvedMet, revisedMet) {
        case (true, true):
            return "You would already have both rings closed today."
        case (true, false):
            return "Solves done. \(revisionGoal - ringsManager.progress.revisions) more to review."
        case (false, true):
            return "Revisions done. \(solveGoal - ringsManager.progress.solves) more to solve."
        case (false, false):
            let remaining = (solveGoal - ringsManager.progress.solves)
                + (revisionGoal - ringsManager.progress.revisions)
            return "\(remaining) more \(remaining == 1 ? "action" : "actions") to close both."
        }
    }

    // MARK: - Rows

    private func goalRow(
        title: String,
        subtitle: String,
        color: Color,
        value: Binding<Int>,
        doneToday: Int
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            GoalStepper(value: value, range: range)

            Text("\(doneToday) today")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .trailing)
        }
        .padding(14)
        .background(Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What is a ring?")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            Text("A ring is one thing you owe today. Close both and the day counts. "
                 + "The outer ring is new solves, the inner one is revisions, and both "
                 + "are measured in your own timezone — so a solve at 1am belongs to the "
                 + "day you were still awake for.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var tomorrowNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)

            Text("Today's rings keep the goals they were opened with. A change applies "
                 + "from tomorrow, so raising a goal never takes away a ring you have "
                 + "already earned.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 3) {
                Text("Could not save")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        await ringsManager.updateGoals(solveGoal: solveGoal, revisionGoal: revisionGoal)

        if ringsManager.saveError == nil {
            dismiss()
        } else {
            // Put the steppers back on the values that actually persisted, so the
            // sheet is not left showing an edit the server refused.
            solveGoal = ringsManager.goals.solveGoal
            revisionGoal = ringsManager.goals.revisionGoal
        }
    }
}

/// A compact −/+ stepper.
///
/// Not `Stepper`: the system control is a label plus a vertical pair of chevrons
/// that reads as a form row, and this is a number the user is choosing while
/// watching a ring redraw. Two round buttons around the value keep the eye on the
/// number.
private struct GoalStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 10) {
            stepButton(systemName: "minus", enabled: value > range.lowerBound) {
                value = max(range.lowerBound, value - 1)
            }

            Text("\(value)")
                .font(.system(size: 20, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .frame(minWidth: 30)

            stepButton(systemName: "plus", enabled: value < range.upperBound) {
                value = min(range.upperBound, value + 1)
            }
        }
    }

    private func stepButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.selection()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(enabled ? .white : .white.opacity(0.25))
                .frame(width: 30, height: 30)
                .background(Circle().fill(.ultraThinMaterial))
        }
        .disabled(!enabled)
        .accessibilityLabel(systemName == "plus" ? "Increase" : "Decrease")
    }
}

#Preview {
    RingGoalsSheet()
}
