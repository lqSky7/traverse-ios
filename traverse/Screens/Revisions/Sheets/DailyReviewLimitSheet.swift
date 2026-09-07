import SwiftUI

struct DailyReviewLimitSheet: View {
    let currentCap: Int
    @Binding var draftCap: Int
    let isSaving: Bool
    let message: String?
    let summary: RevisionTodayResponse?
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    DailyReviewLimitCard(
                        currentCap: currentCap,
                        draftCap: $draftCap,
                        isSaving: isSaving,
                        message: message,
                        summary: summary,
                        onSave: onSave
                    )
                    .padding(20)
                }
            }
            .navigationTitle("Daily Revision Limit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarScrollMinimization()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.height(420), .medium])
    }
}

// MARK: - Revision Analytics Section
