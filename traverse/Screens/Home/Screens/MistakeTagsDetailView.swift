import SwiftUI

struct MistakeTagsDetailView: View {
    let solves: [Solve]
    @ObservedObject var paletteManager: ColorPaletteManager
    
    @State private var searchText = ""
    @State private var selectedDifficulty: String = "All"
    @State private var sortOption: MistakeSortOption = .mostFrequent
    @State private var expandedTags: Set<String> = []
    
    enum MistakeSortOption: String, CaseIterable {
        case mostFrequent = "Most Frequent"
        case leastFrequent = "Least Frequent"
        case alphabetical = "Alphabetical"
    }
    
    struct MistakeSolveSummary: Identifiable {
        let id: String
        let title: String
        let difficulty: String
        let solvedAt: String
    }
    
    struct TagAnalysisItem: Identifiable {
        let id: String
        let tag: String
        let count: Int
        let matchingSolves: [MistakeSolveSummary]
    }
    
    private struct MistakeAnalysisData {
        let allItems: [TagAnalysisItem]
        let displayedItems: [TagAnalysisItem]
        let totalMistakes: Int
        let maxCount: Int
        let cleanPercentage: Int
    }
    
    private var analysisData: MistakeAnalysisData {
        // 1. Filter solves by difficulty
        let difficultyLower = selectedDifficulty.lowercased()
        let filteredSolves: [Solve]
        if selectedDifficulty == "All" {
            filteredSolves = solves
        } else {
            filteredSolves = solves.filter { $0.problem.difficulty.lowercased() == difficultyLower }
        }
        
        // 2. Count mistakes and group solves by tag in one O(N) pass
        var tagCounts: [String: Int] = [:]
        var tagSolves: [String: [MistakeSolveSummary]] = [:]
        var solvesWithMistakes = 0
        
        for solve in filteredSolves {
            let tags = solve.mistakeTags ?? solve.submission.mistakeTags ?? []
            if !tags.isEmpty {
                solvesWithMistakes += 1
                var seen = Set<String>()
                let summary = MistakeSolveSummary(
                    id: "\(solve.id)_\(solve.solvedAt)",
                    title: solve.problem.title,
                    difficulty: solve.problem.difficulty,
                    solvedAt: solve.solvedAt
                )
                for tag in tags {
                    guard seen.insert(tag).inserted else { continue }
                    tagCounts[tag, default: 0] += 1
                    tagSolves[tag, default: []].append(summary)
                }
            }
        }
        
        // 3. Build TagAnalysisItems
        let allItems: [TagAnalysisItem] = tagCounts.map { tag, count in
            TagAnalysisItem(
                id: tag,
                tag: tag,
                count: count,
                matchingSolves: tagSolves[tag] ?? []
            )
        }
        
        let totalMistakes = allItems.reduce(0) { $0 + $1.count }
        let maxCount = max(allItems.map { $0.count }.max() ?? 1, 1)
        
        let cleanSolves = filteredSolves.count - solvesWithMistakes
        let cleanPercentage = filteredSolves.isEmpty ? 100 : Int((Double(max(0, cleanSolves)) / Double(filteredSolves.count)) * 100)
        
        // 4. Search filter
        let searchTrimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredBySearch: [TagAnalysisItem]
        if searchTrimmed.isEmpty {
            filteredBySearch = allItems
        } else {
            filteredBySearch = allItems.filter { item in
                item.tag.localizedCaseInsensitiveContains(searchTrimmed) ||
                item.matchingSolves.contains { $0.title.localizedCaseInsensitiveContains(searchTrimmed) }
            }
        }
        
        // 5. Sort
        let displayedItems: [TagAnalysisItem]
        switch sortOption {
        case .mostFrequent:
            displayedItems = filteredBySearch.sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.tag.localizedCaseInsensitiveCompare($1.tag) == .orderedAscending
            }
        case .leastFrequent:
            displayedItems = filteredBySearch.sorted {
                if $0.count != $1.count { return $0.count < $1.count }
                return $0.tag.localizedCaseInsensitiveCompare($1.tag) == .orderedAscending
            }
        case .alphabetical:
            displayedItems = filteredBySearch.sorted {
                $0.tag.localizedCaseInsensitiveCompare($1.tag) == .orderedAscending
            }
        }
        
        return MistakeAnalysisData(
            allItems: allItems,
            displayedItems: displayedItems,
            totalMistakes: totalMistakes,
            maxCount: maxCount,
            cleanPercentage: cleanPercentage
        )
    }
    
    private func iconForTag(_ tag: String) -> String {
        let lower = tag.lowercased()
        if lower.contains("time") || lower.contains("tle") {
            return "clock.badge.exclamationmark"
        } else if lower.contains("memory") || lower.contains("mle") || lower.contains("space") {
            return "memorychip"
        } else if lower.contains("edge") || lower.contains("corner") || lower.contains("bound") {
            return "exclamationmark.triangle.fill"
        } else if lower.contains("approach") || lower.contains("logic") || lower.contains("algo") {
            return "brain.head.profile"
        } else if lower.contains("base") || lower.contains("recursion") {
            return "arrow.triangle.2.circlepath"
        } else if lower.contains("null") || lower.contains("nil") || lower.contains("pointer") {
            return "questionmark.diamond.fill"
        } else if lower.contains("syntax") || lower.contains("type") {
            return "curlybraces"
        } else if lower.contains("overflow") {
            return "arrow.up.right.and.arrow.down.left.rectangle"
        } else if lower.contains("off-by-one") || lower.contains("index") {
            return "arrow.left.and.right"
        } else {
            return "tag.fill"
        }
    }
    
    private func formattedTagName(_ tag: String) -> String {
        tag.replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
    
    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty.lowercased() {
        case "easy": return .green
        case "medium": return .orange
        case "hard": return .red
        default: return .blue
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: dateString)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: dateString)
        }
        guard let d = date else { return dateString }
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM d"
        return displayFormatter.string(from: d)
    }
    
    var body: some View {
        let data = analysisData
        let totalMistakes = data.totalMistakes
        let maxCount = max(data.maxCount, 1)
        let displayedTags = data.displayedItems
        
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Summary Metrics Row
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(totalMistakes)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(paletteManager.selectedPalette.primary)
                        Text("Total Mistakes")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(data.allItems.count)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(paletteManager.color(at: 2))
                        Text("Mistake Types")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(data.cleanPercentage)%")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(paletteManager.color(at: 1))
                        Text("Clean Solves")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                }
                
                // Difficulty Segmented Picker
                Picker("Difficulty", selection: $selectedDifficulty) {
                    Text("All").tag("All")
                    Text("Easy").tag("Easy")
                    Text("Medium").tag("Medium")
                    Text("Hard").tag("Hard")
                }
                .pickerStyle(.segmented)
                
                // Search Bar & Sort Menu
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search", text: $searchText)
                            .font(.subheadline)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(8)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(10)
                    
                    Menu {
                        Picker("Sort by", selection: $sortOption) {
                            ForEach(MistakeSortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                            Text(sortOption.rawValue)
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(10)
                        .foregroundStyle(paletteManager.selectedPalette.primary)
                    }
                }
                
                // Tags List
                if displayedTags.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(searchText.isEmpty ? "No mistake tags found" : "No results for \"\(searchText)\"")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(displayedTags.enumerated()), id: \.element.id) { index, item in
                            let isExpanded = expandedTags.contains(item.id)
                            let tagColor = paletteManager.color(at: index % 10)
                            let percentage = totalMistakes > 0 ? Int((Double(item.count) / Double(totalMistakes)) * 100) : 0
                            
                            VStack(alignment: .leading, spacing: 10) {
                                // Header row (tappable to expand)
                                Button {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        if isExpanded {
                                            expandedTags.remove(item.id)
                                        } else {
                                            expandedTags.insert(item.id)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(tagColor.opacity(0.18))
                                                .frame(width: 36, height: 36)
                                            Image(systemName: iconForTag(item.tag))
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(tagColor)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(formattedTagName(item.tag))
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.primary)
                                            
                                            Text("\(percentage)% of all mistakes • \(item.matchingSolves.count) \(item.matchingSolves.count == 1 ? "problem" : "problems")")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Text("\(item.count)")
                                            .font(.headline)
                                            .bold()
                                            .foregroundStyle(tagColor)
                                        
                                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Progress Bar
                                GeometryReader { geo in
                                    let ratio = maxCount > 0 ? CGFloat(item.count) / CGFloat(maxCount) : 0
                                    let targetWidth = geo.size.width * ratio
                                    let safeWidth = (targetWidth.isFinite && !targetWidth.isNaN && geo.size.width > 0)
                                        ? max(min(targetWidth, geo.size.width), 8)
                                        : 8

                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 8)
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(
                                                LinearGradient(
                                                    colors: [tagColor, tagColor.opacity(0.7)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: safeWidth, height: 8)
                                    }
                                }
                                .frame(height: 8)
                                
                                // Expanded Problem List
                                if isExpanded {
                                    Divider()
                                        .background(Color.gray.opacity(0.2))
                                        .padding(.vertical, 2)
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Recent Problems")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                        
                                        ForEach(item.matchingSolves) { solve in
                                            HStack(spacing: 8) {
                                                Text(solve.title)
                                                    .font(.caption)
                                                    .foregroundStyle(.primary)
                                                    .lineLimit(1)
                                                
                                                Spacer()
                                                
                                                Text(solve.difficulty.capitalized)
                                                    .font(.system(size: 10, weight: .bold))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(difficultyColor(solve.difficulty).opacity(0.15))
                                                    .foregroundStyle(difficultyColor(solve.difficulty))
                                                    .cornerRadius(4)
                                                
                                                Text(formatDate(solve.solvedAt))
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(.secondary)
                                            }
                                            .padding(.vertical, 3)
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .padding()
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(14)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.black)
        .navigationTitle("Mistake Analysis")
        .navigationBarTitleDisplayMode(.large)
        .toolbarScrollMinimization()
    }
}


// MARK: - Achievement Stats Card (Compact Half-Width)
