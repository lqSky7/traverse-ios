//
//  ProblemsCards.swift
//  traverse
//
//  The two cards that used to sit on the home feed and now head the Problems
//  tab. Nothing about their content changed — they were moved because they are
//  the only cards that need the full solve payload (AI analysis, mistake tags,
//  attempt history), and keeping them on Home meant every pull-to-refresh paid
//  for data that only two cards on a long scroll ever read.
//

import SwiftUI

// MARK: - Recent Solves

struct RecentSolvesCard: View {
    let solves: [Solve]
    @ObservedObject var paletteManager: ColorPaletteManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(paletteManager.color(at: 0))
                    Text("Recent Solves")
                        .font(.headline)
                }
                Spacer()
                NavigationLink(destination: AllSolvesView(solves: solves)) {
                    HStack(spacing: 4) {
                        Text("View All")
                            .font(.subheadline)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundStyle(paletteManager.selectedPalette.primary)
                }
            }
            .padding()

            Divider()
                .background(Color.gray.opacity(0.3))

            // Hero count
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(solves.count)")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(paletteManager.color(at: 0))
                Text("PROBLEMS")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Solve list
            VStack(spacing: 0) {
                ForEach(Array(solves.prefix(5).enumerated()), id: \.element.id) { index, solve in
                    SolveRow(solve: solve, paletteManager: paletteManager)
                    if index < min(4, solves.count - 1) {
                        Divider()
                            .background(Color.gray.opacity(0.3))
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Mistake Analysis

struct MistakeTagsAnalysisCard: View {
    let solves: [Solve]
    @ObservedObject var paletteManager: ColorPaletteManager

    private var cardData: (tagCounts: [(String, Int)], totalTags: Int, maxCount: Int) {
        var counts: [String: Int] = [:]
        for solve in solves {
            if let tags = solve.mistakeTags ?? solve.submission.mistakeTags {
                var seen = Set<String>()
                for tag in tags {
                    guard seen.insert(tag).inserted else { continue }
                    counts[tag, default: 0] += 1
                }
            }
        }
        let sorted = counts.sorted {
            if $0.value != $1.value {
                return $0.value > $1.value
            }
            return $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending
        }
        let total = sorted.reduce(0) { $0 + $1.1 }
        let maxC = max(sorted.map { $0.1 }.max() ?? 1, 1)
        return (sorted, total, maxC)
    }

    var body: some View {
        let data = cardData
        let tagCounts = data.tagCounts
        let totalTags = data.totalTags
        let maxCount = data.maxCount

        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "tag.fill")
                        .foregroundStyle(paletteManager.color(at: 5))
                    Text("Mistake Analysis")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                Spacer()
                HStack(spacing: 6) {
                    Text("\(tagCounts.count)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(paletteManager.color(at: 5))
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, 8)

            Divider()
                .background(Color.gray.opacity(0.3))

            if !tagCounts.isEmpty {
                // Hero total
                VStack(spacing: 4) {
                    Text("\(totalTags)")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Total Mistakes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 12)
                .padding(.bottom, 16)

                // Horizontal bars for TOP 3 tags
                VStack(spacing: 12) {
                    ForEach(Array(tagCounts.prefix(3).enumerated()), id: \.element.0) { index, item in
                        MistakeTagProgressRow(
                            label: item.0,
                            count: item.1,
                            maxCount: maxCount,
                            color: paletteManager.color(at: index % 10)
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            } else {
                // "No mistakes" is good news, so this one reads as a pass rather
                // than a failure — it keeps the checkmark and the encouraging
                // second line instead of the neutral empty-state shell.
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: "No mistakes detected",
                    message: "Traverse reads the AI analysis of your attempts. Recurring mistakes start showing up after a few solves.",
                    compact: true
                )
                .frame(minHeight: 120)
                .padding()
            }
        }
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Mistake Tag Progress Row
struct MistakeTagProgressRow: View {
    let label: String
    let count: Int
    let maxCount: Int
    let color: Color

    private var progress: CGFloat {
        guard maxCount > 0 else { return 0 }
        let p = CGFloat(count) / CGFloat(maxCount)
        return (p.isFinite && !p.isNaN) ? min(max(p, 0), 1) : 0
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
                .lineLimit(1)

            GeometryReader { geometry in
                let targetWidth = geometry.size.width * progress
                let safeWidth = (targetWidth.isFinite && !targetWidth.isNaN && geometry.size.width > 0)
                    ? max(min(targetWidth, geometry.size.width), count > 0 ? 12 : 0)
                    : (count > 0 ? 12 : 0)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: safeWidth, height: 12)
                }
            }
            .frame(height: 12)

            Text("\(count)")
                .font(.subheadline)
                .bold()
                .foregroundStyle(color)
                .frame(width: 30, alignment: .trailing)
        }
    }
}
