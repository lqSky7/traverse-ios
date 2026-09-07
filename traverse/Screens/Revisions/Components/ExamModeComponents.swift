import SwiftUI

struct DailyReviewLimitCard: View {
    let currentCap: Int
    @Binding var draftCap: Int
    let isSaving: Bool
    let message: String?
    let summary: RevisionTodayResponse?
    let onSave: () -> Void
    @StateObject private var paletteManager = ColorPaletteManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(paletteManager.color(at: 2))
                    Text("Daily Review Limit")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                Spacer()
            }

            Text("Cap the number of ML revisions shown each day. Overflow rolls into the next days.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Stepper(value: $draftCap, in: 1...200) {
                HStack {
                    Text("Max per day")
                        .font(.subheadline)
                    Spacer()
                    Text("\(draftCap)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(paletteManager.selectedPalette.primary)
                }
            }

            if let summary = summary {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(summary.revisions.count)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(paletteManager.color(at: 1))
                        Text("Showing")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(summary.total)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        Text("Total Due")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(summary.overflow)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(paletteManager.color(at: 0))
                        Text("Overflow")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let message = message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(action: onSave) {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else {
                    Text("Save Limit")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .tint(paletteManager.selectedPalette.primary)
            .buttonStyle(.borderedProminent)
            .disabled(isSaving || draftCap == currentCap)
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Daily Review Limit Sheet

struct ExamModeActiveView: View {
    @ObservedObject var paletteManager = ColorPaletteManager.shared
    let isResuming: Bool
    let onResume: () -> Void

    @State private var tiltPosition: CGPoint = CGPoint(x: 170, y: 140)
    private let motionManager = CMMotionManager()

    var body: some View {
        VStack {
            Spacer()

            // Light & Tilt Shader Surface with Glass Container on Top
            ZStack {
                // Background Light & Tilt Shader Layer
                RoundedRectangle(cornerRadius: 32)
                    .fill(
                        LinearGradient(
                            colors: [
                                paletteManager.selectedPalette.primary.opacity(0.8),
                                paletteManager.color(at: 2).opacity(0.6),
                                paletteManager.color(at: 1).opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .layerEffect(
                        ShaderLibrary.shine(
                            .boundingRect,
                            .float2(tiltPosition),
                            .float(0.57),
                            .float(3.8)
                        ),
                        maxSampleOffset: .zero
                    )
                    .blur(radius: 4)
                    .cornerRadius(32)
                    .shadow(color: paletteManager.selectedPalette.primary.opacity(0.35), radius: 24, x: 0, y: 12)

                // Glass Container on top of Shader Layer
                VStack(spacing: 20) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Exam Mode")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)

                    Button(action: onResume) {
                        HStack(spacing: 8) {
                            if isResuming {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Stop Exam Mode")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.2), in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .disabled(isResuming)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
                .modifier(LiquidGlassCardModifier())
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.white.opacity(0.25), lineWidth: 1)
                )
                .padding(12)
            }
            .frame(maxWidth: 360)
            .padding(.horizontal, 24)

            Spacer()
        }
        .onAppear {
            if motionManager.isDeviceMotionAvailable {
                motionManager.startDeviceMotionUpdates(to: .main) { motion, error in
                    guard let motion = motion else { return }
                    let x = motion.attitude.roll
                    let y = motion.attitude.pitch
                    tiltPosition = CGPoint(x: 180 + CGFloat(x) * 50, y: 140 + CGFloat(y) * 50)
                }
            }
        }
        .onDisappear {
            motionManager.stopDeviceMotionUpdates()
        }
    }
}

// MARK: - Pause Exam Mode Sheet
