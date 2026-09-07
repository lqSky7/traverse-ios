import SwiftUI

struct AllTopicsSheet: View {
    let topics: [RevisionTopicMetric]
    @Environment(\.dismiss) private var dismiss
    @StateObject private var paletteManager = ColorPaletteManager.shared
    @State private var searchText = ""
    @State private var sortOption: TopicSortOption = .lowestRetention

    enum TopicSortOption: String, CaseIterable {
        case lowestRetention = "Lowest Retention"
        case highestRetention = "Highest Retention"
        case mostProblems = "Most Problems"
        case slowestTime = "Solve Time"
    }

    private var filteredTopics: [RevisionTopicMetric] {
        let list = searchText.isEmpty
            ? topics
            : topics.filter { $0.topic.localizedCaseInsensitiveContains(searchText) }

        switch sortOption {
        case .lowestRetention:
            return list.sorted { $0.averageRetention < $1.averageRetention }
        case .highestRetention:
            return list.sorted { $0.averageRetention > $1.averageRetention }
        case .mostProblems:
            return list.sorted { $0.problemCount > $1.problemCount }
        case .slowestTime:
            return list.sorted { $0.averageTimeMinutes > $1.averageTimeMinutes }
        }
    }

    private func retentionColor(for retention: Double) -> Color {
        if retention >= 0.80 {
            return paletteManager.color(at: 3)
        } else if retention >= 0.60 {
            return paletteManager.color(at: 1)
        } else {
            return paletteManager.color(at: 0)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Sort by", selection: $sortOption) {
                        ForEach(TopicSortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    if filteredTopics.isEmpty {
                        Text("No matching topics")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 16)
                    } else {
                        ForEach(filteredTopics) { topic in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(topic.displayTopic)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    if topic.averageTimeMinutes > 0 {
                                        HStack(spacing: 3) {
                                            Image(systemName: "clock")
                                                .font(.caption2)
                                            Text(String(format: "%.1fm avg", topic.averageTimeMinutes))
                                                .font(.caption2)
                                        }
                                        .foregroundStyle(.secondary)
                                    }

                                    Text(String(format: "%.0f%%", topic.averageRetention * 100))
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(retentionColor(for: topic.averageRetention))
                                }

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 6)
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(retentionColor(for: topic.averageRetention))
                                            .frame(width: max(geo.size.width * CGFloat(min(max(topic.averageRetention, 0), 1.0)), 4), height: 6)
                                    }
                                }
                                .frame(height: 6)

                                HStack {
                                    Text("\(topic.problemCount) \(topic.problemCount == 1 ? "problem" : "problems")")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)

                                    Spacer()

                                    Text(String(format: "Avg Stability: %.1fd", topic.averageStability))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search topics")
            .navigationTitle("All Topics (\(topics.count))")
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

// MARK: - At-Risk Problems Card (Top 5 + Full Sheet)
