//
//  ProblemsView.swift
//  traverse
//
//  New home for Recent Solves and Mistake Analysis.
//
//  Both cards read the full solve payload — AI analysis, mistake tags, attempt
//  history — which is the most expensive thing the API returns. They were on
//  the home feed, which meant every pull-to-refresh paid for them even when the
//  user never scrolled that far. Giving them their own tab lets Home ask for a
//  small page and lets this screen ask for a deep one, on demand.
//

import SwiftUI

struct ProblemsTab: View {
    var body: some View {
        ProblemsView()
    }
}

struct ProblemsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ProblemsViewModel()
    @ObservedObject var paletteManager = ColorPaletteManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                // LazyVStack for the same reason HomeView uses one: the solve
                // list is long, and this tab stays mounted once opened.
                LazyVStack(spacing: 20) {
                    if let solves = viewModel.solves, !solves.isEmpty {
                        NavigationLink(destination: MistakeTagsDetailView(solves: solves, paletteManager: paletteManager)) {
                            MistakeTagsAnalysisCard(solves: solves, paletteManager: paletteManager)
                        }
                        .buttonStyle(PlainButtonStyle())

                        RecentSolvesCard(solves: solves, paletteManager: paletteManager)
                    } else if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: paletteManager.selectedPalette.primary))
                            .padding(.top, 80)
                    } else if let error = viewModel.errorMessage {
                        ErrorView(message: error) {
                            Task { await viewModel.load(forceRefresh: true) }
                        }
                    } else {
                        emptyState
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Problems")
            .navigationBarTitleDisplayMode(.large)
            .toolbarScrollMinimization()
            .refreshable {
                // Wrapped in a Task so the pull-to-refresh gesture ending does
                // not cancel the in-flight request.
                await Task {
                    await viewModel.load(forceRefresh: true)
                }.value
            }
        }
        .onAppear {
            if let username = authViewModel.currentUser?.username {
                print("[ProblemsView] onAppear username=\(username)")
            }
            Task { await viewModel.load() }
        }
        .preferredColorScheme(.dark)
    }

    private var emptyState: some View {
        // Both cards on this tab are built from the solve payload, so "empty"
        // here always means the account has never solved anything — not that a
        // filter excluded everything. That makes the extension the answer, not
        // "try a different filter".
        GettingStartedEmptyState(
            title: "No problems yet",
            message: "Recent solves and recurring mistakes appear here once Traverse has seen you solve something in the browser."
        )
    }
}

#Preview {
    ProblemsView()
        .environmentObject(AuthViewModel())
        .preferredColorScheme(.dark)
}
