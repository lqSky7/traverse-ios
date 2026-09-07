import SwiftUI

struct AllAtRiskProblemsSheet: View {
    let items: [RevisionRetentionItem]
    @Environment(\.dismiss) private var dismiss
    @StateObject private var paletteManager = ColorPaletteManager.shared
    @State private var searchText = ""
    @State private var sortOption: RiskSortOption = .lowestRetention

    enum RiskSortOption: String, CaseIterable {
        case lowestRetention = "Lowest Retention"
        case mostLapses = "Most Lapses"
        case alphabetical = "Alphabetical"
    }

    private var filteredItems: [RevisionRetentionItem] {
        let list = searchText.isEmpty
            ? items
            : items.filter { $0.problemTitle.localizedCaseInsensitiveContains(searchText) }

        switch sortOption {
        case .lowestRetention:
            return list.sorted { $0.retrievability < $1.retrievability }
        case .mostLapses:
            return list.sorted { $0.lapses > $1.lapses }
        case .alphabetical:
            return list.sorted { $0.problemTitle.localizedCaseInsensitiveCompare($1.problemTitle) == .orderedAscending }
        }
    }

    private func riskColor(for item: RevisionRetentionItem) -> Color {
        if item.isLeech || item.retrievability < 0.5 {
            return paletteManager.color(at: 0)
        }
        if item.retrievability < 0.7 {
            return paletteManager.color(at: 1)
        }
        return paletteManager.color(at: 2)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Sort by", selection: $sortOption) {
                        ForEach(RiskSortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    if filteredItems.isEmpty {
                        Text("No matching problems")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 16)
                    } else {
                        ForEach(filteredItems) { item in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(riskColor(for: item))
                                    .frame(width: 10, height: 10)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.problemTitle)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    HStack(spacing: 8) {
                                        Text("\(item.platform.capitalized) • \(item.difficulty.capitalized)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)

                                        if item.isLeech {
                                            Text("Leech (\(item.lapses) lapses)")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(paletteManager.color(at: 0))
                                        } else if item.lapses > 0 {
                                            Text("\(item.lapses) lapses")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(String(format: "%.0f%%", item.retrievability * 100))
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(riskColor(for: item))

                                    Text(String(format: "%.1fd stability", item.stability))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search problems")
            .navigationTitle("At-Risk Problems (\(items.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarScrollMinimization()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

// MARK: - ML Scheduling Info Sheet
