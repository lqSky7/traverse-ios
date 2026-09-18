import SwiftUI

/// One award shelf, opened. A three-up grid of badges — the layout Apple uses for
/// "Close Your Rings" and "Monthly Challenges" in the Fitness app.
struct AwardsSectionView: View {
    let section: AwardSection
    @State private var selectedAward: AchievementDetail?

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 12, alignment: .top),
        count: 3
    )

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !section.subtitle.isEmpty {
                        Text(section.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if section.achievements.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                            ForEach(section.achievements) { award in
                                Button {
                                    selectedAward = award
                                } label: {
                                    AwardGridCell(award: award)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(section.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbarScrollMinimization()
        .sheet(item: $selectedAward) { award in
            AwardDetailSheet(award: award)
        }
        .preferredColorScheme(.dark)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "trophy")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.2))
            Text(section.emptyCopy)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Grid cell

private struct AwardGridCell: View {
    let award: AchievementDetail
    @ObservedObject private var paletteManager = ColorPaletteManager.shared

    private var showsProgress: Bool {
        !award.unlocked && (award.progress?.fraction ?? 0) > 0
    }

    var body: some View {
        VStack(spacing: 6) {
            MedalView(
                medal: award.medalAsset,
                unlocked: award.unlocked,
                size: 72,
                // Static in the grid. The tilt gesture lives in the sheet below, where
                // it can't make every badge draggable or swallow the back-swipe.
                interactive: false,
                showsShadow: false
            )
            .frame(height: 76)

            Text(award.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(award.unlocked ? .white : Color.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)

            if showsProgress, let progress = award.progress {
                VStack(spacing: 4) {
                    Text(progress.caption)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    MedalProgressBar(
                        fraction: progress.fraction,
                        width: 72,
                        tint: paletteManager.color(at: 1)
                    )
                }
            } else {
                Text(AwardFormat.caption(for: award))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Badge detail

/// Tapping a badge opens it: a large badge you can hold and drag to tilt.
struct AwardDetailSheet: View {
    let award: AchievementDetail
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var paletteManager = ColorPaletteManager.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)

                Spacer(minLength: 0)

                MedalView(
                    medal: award.medalAsset,
                    unlocked: award.unlocked,
                    size: 240,
                    // The one place a badge is tiltable — the user has tapped it open,
                    // so there is no scroll view or back-swipe to fight here.
                    interactive: true
                )

                Text("Hold and drag the badge to tilt it")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                VStack(spacing: 6) {
                    Text(award.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(award.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let progress = award.progress, !award.unlocked {
                    VStack(spacing: 8) {
                        Text(progress.caption)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        MedalProgressBar(
                            fraction: progress.fraction,
                            width: 160,
                            tint: paletteManager.color(at: 1)
                        )
                    }
                    .padding(.top, 4)
                } else if award.unlocked, let stamp = AwardFormat.shortDate(award.unlockedAt) {
                    Label("Earned \(stamp)", systemImage: "checkmark.seal.fill")
                        .font(.subheadline)
                        .foregroundStyle(paletteManager.color(at: 1))
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 32)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }
}
