import SwiftUI

/// The full solve list — the destination behind "View All" on the home feed.
///
/// It is also how a profile renders someone else's history, which is why it
/// takes a `title` and an optional paging callback: a friend's feed is
/// cursor-paginated on the server, so the list has to be able to pull the next
/// page rather than assume it holds everything.
struct AllSolvesView: View {
    let solves: [Solve]
    var title: String = "All Solves"
    /// Invoked when the end of the list is reached and the server reported more
    /// rows. The caller is responsible for ignoring repeat calls.
    var onLoadMore: (() async -> Void)?

    @ObservedObject var paletteManager = ColorPaletteManager.shared
    @State private var searchText = ""
    @State private var selectedTopic: String? = nil
    @State private var isLoadingMore = false

    var availableTopics: [String] {
        let allTopics = solves.compactMap { $0.problem.topic }
        return Array(Set(allTopics)).filter { !$0.isEmpty }.sorted()
    }

    var filteredSolves: [Solve] {
        solves.filter { solve in
            let matchesSearch = searchText.isEmpty ||
                solve.problem.title.localizedCaseInsensitiveContains(searchText) ||
                solve.problem.slug.localizedCaseInsensitiveContains(searchText) ||
                (solve.problem.topic ?? "").localizedCaseInsensitiveContains(searchText) ||
                (solve.problem.subtopic ?? "").localizedCaseInsensitiveContains(searchText)

            let matchesTopic = selectedTopic == nil || solve.problem.topic == selectedTopic

            return matchesSearch && matchesTopic
        }
    }

    /// Only page while the user is looking at the unfiltered list — pulling more
    /// rows behind an active search would grow the list under a filter that
    /// cannot use them.
    private var canLoadMore: Bool {
        onLoadMore != nil && searchText.isEmpty && selectedTopic == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search problems, topics, subtopics...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Topic Filter ScrollView
            if !availableTopics.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button(action: {
                            withAnimation {
                                selectedTopic = nil
                            }
                        }) {
                            Text("All Topics")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedTopic == nil ? paletteManager.selectedPalette.primary : Color.white.opacity(0.1))
                                .foregroundColor(selectedTopic == nil ? .black : .white)
                                .cornerRadius(12)
                        }
                        
                        ForEach(availableTopics, id: \.self) { topic in
                            Button(action: {
                                withAnimation {
                                    if selectedTopic == topic {
                                        selectedTopic = nil
                                    } else {
                                        selectedTopic = topic
                                    }
                                }
                            }) {
                                Text(topic)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedTopic == topic ? paletteManager.selectedPalette.primary : Color.white.opacity(0.1))
                                    .foregroundColor(selectedTopic == topic ? .black : .white)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
            }
            
            // Solves List
            ScrollView {
                if filteredSolves.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "square.dashed")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No solves match your criteria")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredSolves) { solve in
                            SolveRow(solve: solve, paletteManager: paletteManager)
                        }

                        if canLoadMore {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            // Fires when the footer scrolls into view, which is
                            // when the next page is actually wanted.
                            .task {
                                guard !isLoadingMore else { return }
                                isLoadingMore = true
                                await onLoadMore?()
                                isLoadingMore = false
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarScrollMinimization()
    }
}

