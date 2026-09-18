import SwiftUI

/// Someone else's solve history, rendered with the home screen's solve list.
///
/// All of the presentation lives in `AllSolvesView` — the same search field,
/// topic filter and `SolveRow` the home feed uses. This view only fetches, so
/// there is exactly one solve list in the app to keep working, and a change to
/// it shows up on the profile for free.
///
/// It replaces the inline `SolvesListView` the profile used to embed, which was
/// a second, thinner list that had its own model and its own bugs.
struct ProfileSolvesView: View {
    let username: String
    /// Decides which endpoint is read. The server, not the client, decides how
    /// much detail comes back — this only picks the gate that applies.
    let isFriend: Bool

    private let pageSize = 30

    @State private var solves: [Solve] = []
    @State private var nextCursor: Int?
    @State private var hasMore = false
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var errorMessage: String?

    var body: some View {
        content
            .task {
                if solves.isEmpty { await reload() }
            }
            .refreshable {
                await reload()
            }
            .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && solves.isEmpty {
            loadingState
        } else if errorMessage != nil && solves.isEmpty {
            errorState
        } else if solves.isEmpty {
            emptyState
        } else {
            AllSolvesView(
                solves: solves,
                title: "\(username)'s Solves",
                onLoadMore: loadMoreHandler
            )
        }
    }

    /// `nil` disables paging in `AllSolvesView`; built as a stored value rather
    /// than inline in the call site so the view body stays cheap to type-check.
    private var loadMoreHandler: (() async -> Void)? {
        guard hasMore else { return nil }
        return { await loadNextPage() }
    }

    private var loadingState: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
    }

    private var errorState: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ErrorView(message: errorMessage ?? "Something went wrong", retry: {
                Task { await reload() }
            })
        }
    }

    private var emptyState: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            EmptyStateView(
                icon: "square.dashed",
                title: "No Solves Yet",
                message: "@\(username) has not logged a solve yet."
            )
        }
    }

    // MARK: - Loading

    private func reload() async {
        if solves.isEmpty { isLoading = true }
        errorMessage = nil
        nextCursor = nil
        hasMore = false
        solves = []
        await loadNextPage()
        isLoading = false
    }

    private func loadNextPage() async {
        guard !isLoadingMore else { return }

        // The friend feed is cursor-paginated — it grows at the front, so an
        // offset would shift under the reader and pages would duplicate or skip
        // rows. The public profile feed still reports an offset.
        let isFirstPage = solves.isEmpty
        if !isFirstPage { isLoadingMore = true }
        defer { isLoadingMore = false }

        do {
            let response: UserSolvesResponse
            if isFriend {
                response = try await NetworkService.shared.getFriendSolves(
                    username: username,
                    limit: pageSize,
                    cursor: isFirstPage ? nil : nextCursor
                )
            } else {
                response = try await NetworkService.shared.getUserSolves(
                    username: username,
                    limit: pageSize,
                    offset: isFirstPage ? 0 : solves.count
                )
            }

            append(response.solves)

            nextCursor = response.pagination.nextCursor
            if isFriend {
                hasMore = response.pagination.nextCursor != nil
            } else {
                hasMore = solves.count < response.pagination.total
            }
        } catch is CancellationError {
            // Ignore - the view went away.
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            // Ignore - request was cancelled.
        } catch {
            if solves.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// De-duplicates on append. A row can legitimately repeat across pages if a
    /// new solve lands while the reader is paging, and a repeated `id` in a
    /// `ForEach` is a hard crash rather than a cosmetic glitch.
    private func append(_ incoming: [Solve]) {
        guard !solves.isEmpty else {
            solves = incoming
            return
        }
        let seen = Set(solves.map(\.id))
        solves.append(contentsOf: incoming.filter { !seen.contains($0.id) })
    }
}
