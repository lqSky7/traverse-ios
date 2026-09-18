//
//  RevisionLoadDetailView.swift
//  traverse
//
//  The pushed view behind the home feed's Revision Load card, laid out like
//  Apple Fitness' Training Load detail screen: scope chips across the top, the
//  band word in colour, the 7-day vs baseline comparison, a paragraph of plain
//  language, then a daily trend with the baseline drawn through it.
//
//  Colours come from `ColorPaletteManager`, not from a hard-coded Apple ramp —
//  a card that ignores the user's chosen palette looks pasted onto the feed.
//
//  Scope changes are animated rather than `.id`-swapped. Every scope draws the
//  same day-keyed series, so the marks keep their identity and interpolate;
//  the chart morphs instead of cutting.
//

import SwiftUI
import Charts

struct RevisionLoadDetailView: View {
    let breakdown: RevisionLoadBreakdown
    let revisionScore: Int?
    @ObservedObject var paletteManager: ColorPaletteManager

    @State private var scope: LoadScope = .all
    @State private var showExplanationSheet = false

    private var snapshot: RevisionLoadSnapshot { breakdown.snapshot(for: scope) }
    private var accent: Color { paletteManager.loadColor(for: snapshot.band) }

    private var upperBound: Double {
        max(snapshot.series.map(\.value).max() ?? 0, 1) * 1.25
    }

    /// Explicit domain so the axis does not jitter when a scope has a shorter
    /// history than the last one and the series changes length mid-animation.
    private var xDomain: ClosedRange<Date> {
        guard let first = snapshot.series.first?.day,
              let last = snapshot.series.last?.day,
              first < last else {
            let now = Date()
            return now.addingTimeInterval(-3600)...now
        }
        return first...last
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                scopeChips

                VStack(alignment: .leading, spacing: 18) {
                    statusBlock
                    Text(snapshot.band.explanation)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                    trendChart
                    Divider().overlay(Color.white.opacity(0.12))
                    footerRows
                }
                .padding(16)
                .background(Color(UIColor.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Color.black)
        .navigationTitle("Revision Load")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarScrollMinimization()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticManager.shared.selection()
                    showExplanationSheet = true
                } label: {
                    Image(systemName: "info")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.14)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("About revision load")
            }
        }
        .sheet(isPresented: $showExplanationSheet) {
            RevisionLoadExplanationSheet()
        }
    }

    // MARK: Scope chips

    private var scopeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(LoadScope.allCases) { candidate in
                    let candidateSnapshot = breakdown.snapshot(for: candidate)
                    let isSelected = candidate == scope

                    Button {
                        HapticManager.shared.selection()
                        withAnimation(.smooth(duration: 0.45)) { scope = candidate }
                    } label: {
                        HStack(spacing: 6) {
                            Text(candidate.title)
                                .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(.white)

                            if let percent = candidateSnapshot.formattedPercentChange {
                                Text(percent)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(paletteManager.loadColor(for: candidateSnapshot.band))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(Color.white.opacity(isSelected ? 0.20 : 0.08))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }

    // MARK: Status

    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.band.rawValue)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(subtitle)
                .font(.system(size: 14, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(Color.white.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subtitle: String {
        guard let percent = snapshot.formattedPercentChange else {
            return snapshot.comparisonLabel
        }
        return "\(percent) · \(snapshot.comparisonLabel)"
    }

    // MARK: Chart

    private var trendChart: some View {
        Chart {
            if snapshot.hasData, snapshot.baselineDailyAverage > 0 {
                RuleMark(y: .value("Baseline", snapshot.baselineDailyAverage))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            }

            ForEach(snapshot.series) { point in
                LineMark(
                    x: .value("Day", point.day),
                    y: .value("Load", point.value)
                )
                .foregroundStyle(Color.white.opacity(0.28))
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                .interpolationMethod(.catmullRom)
            }

            ForEach(snapshot.series) { point in
                PointMark(
                    x: .value("Day", point.day),
                    y: .value("Load", point.value)
                )
                .foregroundStyle(paletteManager.loadColor(for: snapshot.band(for: point.value)))
                .symbolSize(point.id == snapshot.series.last?.id ? 110 : 45)
            }
        }
        .chartYScale(domain: 0...upperBound)
        .chartXScale(domain: xDomain)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(Color.white.opacity(0.18))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                }
            }
        }
        .frame(height: 190)
        .padding(.top, 4)
        // Marks are keyed by day in both scopes, so the series interpolates
        // rather than cutting. Scoped to `scope` so nothing else re-animates.
        .animation(.smooth(duration: 0.45), value: scope)
    }

    // MARK: Footer

    private var footerRows: some View {
        VStack(spacing: 12) {
            footerRow(
                title: "Revision Score",
                value: revisionScore.map(String.init),
                valueColor: Color.white.opacity(0.85)
            )
            footerRow(
                title: snapshot.baselineLabel,
                value: snapshot.hasData ? String(format: "%.1f", snapshot.baselineDailyAverage) : nil,
                valueColor: Color.white.opacity(0.85)
            )
        }
    }

    private func footerRow(title: String, value: String?, valueColor: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            Spacer(minLength: 0)

            Text(value ?? "No Data")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(value == nil ? Color.white.opacity(0.45) : valueColor)
        }
    }
}

#Preview {
    NavigationStack {
        RevisionLoadDetailView(
            breakdown: .empty,
            revisionScore: 87,
            paletteManager: ColorPaletteManager.shared
        )
    }
    .preferredColorScheme(.dark)
}
