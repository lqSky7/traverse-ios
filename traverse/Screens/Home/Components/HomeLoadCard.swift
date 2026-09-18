//
//  HomeLoadCard.swift
//  traverse
//
//  Home-feed summary of revision load, modelled on Apple Fitness' "Training
//  Load" tile: a small gauge on the left, the band word in colour on the right,
//  the 7-day vs 28-day comparison underneath, and a second metric sharing the
//  card's footer.
//
//  This replaces the old `RevisionScoreCard` (a bare number with a shader orb
//  bleeding out of the corner). The score itself did not go away — it moved to
//  the footer row, where it reads as one fact among several instead of the only
//  fact on the card.
//

import SwiftUI

struct RevisionLoadCard: View {
    let breakdown: RevisionLoadBreakdown?
    let revisionScore: Int?
    @ObservedObject var paletteManager: ColorPaletteManager

    private var snapshot: RevisionLoadSnapshot { breakdown?.overall ?? .empty }
    private var accent: Color { paletteManager.loadColor(for: snapshot.band) }

    private var subtitle: String {
        guard let percent = snapshot.formattedPercentChange else {
            return snapshot.comparisonLabel
        }
        return "\(percent) · \(snapshot.comparisonLabel)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Revision Load")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)

            HStack(alignment: .center, spacing: 16) {
                RevisionLoadGauge(snapshot: snapshot, accent: accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.band.rawValue)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.white.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }

                Spacer(minLength: 0)
            }

            Divider()
                .overlay(Color.white.opacity(0.12))

            HStack(spacing: 8) {
                Text("Revision Score")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer(minLength: 0)

                Text(revisionScore.map(String.init) ?? "No Data")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(revisionScore == nil ? Color.white.opacity(0.45) : Color.white.opacity(0.85))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .traceInvalidFrame("RevisionLoadCard")
    }
}

/// The stacked-bar gauge from the reference card: two neutral caps around a
/// coloured block, with a white progress pill underneath showing where the
/// 7-day average sits against baseline.
///
/// Flat by design — the block used to carry a coloured drop shadow and the dot
/// a blurred halo, which on a black background read as a glow bleeding into the
/// card. The band colour is already the signal; it does not need to be emitted.
///
/// Everything here is static — no `TimelineView`, no repeating animation. The
/// card's job is to communicate a number, and the codebase already has a
/// cautionary tale (see `ThinkingOrbScoreView`'s removal) about what an
/// always-on animation in a tab that never unloads does to battery life.
struct RevisionLoadGauge: View {
    let snapshot: RevisionLoadSnapshot
    let accent: Color

    private var fillFraction: CGFloat {
        guard snapshot.hasData, snapshot.baselineDailyAverage > 0 else { return 0.06 }
        let ratio = snapshot.recentDailyAverage / snapshot.baselineDailyAverage
        // Half of baseline sits at the low end, twice baseline fills the pill.
        return CGFloat(min(max(ratio / 2.0, 0.06), 1.0))
    }

    var body: some View {
        VStack(spacing: 4) {
            cap

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.90), accent.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 84, height: 52)

                ZStack {
                    Circle()
                        .fill(accent)
                        .frame(width: 20, height: 20)
                    Circle()
                        .fill(Color.black.opacity(0.85))
                        .frame(width: 9, height: 9)
                }
            }
            .frame(width: 84, height: 52)

            cap

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 74, height: 4)
                Capsule()
                    .fill(Color.white)
                    .frame(width: max(74 * fillFraction, 5), height: 4)
            }
            .frame(width: 74, height: 4)
        }
        .frame(width: 84)
    }

    private var cap: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Color.white.opacity(0.14))
            .frame(width: 74, height: 16)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            RevisionLoadCard(
                breakdown: nil,
                revisionScore: 87,
                paletteManager: ColorPaletteManager.shared
            )
            RevisionLoadCard(
                breakdown: nil,
                revisionScore: nil,
                paletteManager: ColorPaletteManager.shared
            )
        }
        .padding()
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
}
