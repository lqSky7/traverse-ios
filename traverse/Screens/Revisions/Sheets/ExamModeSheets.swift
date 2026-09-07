import SwiftUI

struct PauseExamModeSheet: View {
    @ObservedObject var paletteManager = ColorPaletteManager.shared
    @Environment(\.dismiss) private var dismiss
    @Binding var pauseDays: Int
    let isSubmitting: Bool
    let onConfirm: (Int) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(paletteManager.selectedPalette.primary.opacity(0.12))
                                .frame(width: 64, height: 64)

                            Image(systemName: "graduationcap.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(paletteManager.selectedPalette.primary)
                        }

                        Text("Pause Revisions")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        Text("Pause scheduled revisions while preparing for exams. Your calendar feed will display daily quotes.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)

                    // Glass Stepper Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PAUSE DURATION")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("\(pauseDays) Days")
                                .font(.headline)
                                .foregroundStyle(.white)

                            Spacer()

                            Stepper("", value: $pauseDays, in: 1...30)
                                .labelsHidden()
                        }
                        .padding()
                        .modifier(LiquidGlassCardModifier())
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)

                    Spacer()

                    Button(action: { onConfirm(pauseDays) }) {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Confirm Pause")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .foregroundStyle(.white)
                                .background(
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(paletteManager.selectedPalette.primary.opacity(0.3))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 24)
                                                .stroke(paletteManager.selectedPalette.primary.opacity(0.5), lineWidth: 1)
                                        )
                                )
                        }
                    }
                    .disabled(isSubmitting)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Exam Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarScrollMinimization()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Resume Revisions Sheet
struct ResumeRevisionsSheet: View {
    @ObservedObject var paletteManager = ColorPaletteManager.shared
    @Environment(\.dismiss) private var dismiss
    @Binding var backlogDays: Int
    let isSubmitting: Bool
    let onConfirm: (Int) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(paletteManager.selectedPalette.primary.opacity(0.12))
                                .frame(width: 64, height: 64)

                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(paletteManager.selectedPalette.primary)
                        }

                        Text("Resume Revisions")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        Text("Spread accumulated backlog over a period of days.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)

                    // Glass Stepper Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SPREAD BACKLOG OVER")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("\(backlogDays) Days")
                                .font(.headline)
                                .foregroundStyle(.white)

                            Spacer()

                            Stepper("", value: $backlogDays, in: 1...14)
                                .labelsHidden()
                        }
                        .padding()
                        .modifier(LiquidGlassCardModifier())
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)

                    Spacer()

                    Button(action: { onConfirm(backlogDays) }) {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Resume Schedule")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .foregroundStyle(.white)
                                .background(
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(paletteManager.selectedPalette.primary.opacity(0.3))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 24)
                                                .stroke(paletteManager.selectedPalette.primary.opacity(0.5), lineWidth: 1)
                                        )
                                )
                        }
                    }
                    .disabled(isSubmitting)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Catch Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarScrollMinimization()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RevisionsView()
        .environmentObject(AuthViewModel())
}

