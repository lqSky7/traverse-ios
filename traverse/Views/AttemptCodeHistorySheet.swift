//
//  AttemptCodeHistorySheet.swift
//  traverse
//
//  Dedicated sheet for inspecting raw attempt code history.
//

import SwiftUI

struct AttemptCodeHistorySheet: View {
    let problemTitle: String
    let previousAttempts: [CodeAttempt]
    let todayAttempts: [CodeAttempt]
    @ObservedObject var paletteManager = ColorPaletteManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if previousAttempts.isEmpty && todayAttempts.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "tray")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary)
                                Text("No raw attempt code stored for this problem.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        } else {
                            if !previousAttempts.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Previous Session Attempts (\(previousAttempts.count))")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(paletteManager.color(at: 4))
                                        .textCase(.uppercase)

                                    ForEach(Array(previousAttempts.enumerated()), id: \.offset) { idx, att in
                                        CodeAttemptCard(
                                            index: idx + 1,
                                            attempt: att,
                                            isToday: false,
                                            paletteManager: paletteManager
                                        )
                                    }
                                }
                            }

                            if !todayAttempts.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Today's Session Attempts (\(todayAttempts.count))")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(paletteManager.color(at: 1))
                                        .textCase(.uppercase)

                                    ForEach(Array(todayAttempts.enumerated()), id: \.offset) { idx, att in
                                        CodeAttemptCard(
                                            index: idx + 1,
                                            attempt: att,
                                            isToday: true,
                                            paletteManager: paletteManager
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("\(problemTitle) History")
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
    }
}

private struct CodeAttemptCard: View {
    let index: Int
    let attempt: CodeAttempt
    let isToday: Bool
    @ObservedObject var paletteManager: ColorPaletteManager
    @State private var isExpanded = true

    private var isAccepted: Bool {
        attempt.successful == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: isAccepted ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(isAccepted ? paletteManager.color(at: 1) : .orange)
                            .font(.headline)

                        Text("\(isToday ? "Today" : "Prev") Attempt #\(index)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        Text("(\(attempt.type?.capitalized ?? "Run"))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                if let code = attempt.code, !code.isEmpty {
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(code)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.95))
                            .padding(12)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                    }
                } else {
                    Text("No code snippet stored for this attempt.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .glassEffect(.clear.tint(.black.opacity(0.2)), in: .rect(cornerRadius: 16))
    }
}
