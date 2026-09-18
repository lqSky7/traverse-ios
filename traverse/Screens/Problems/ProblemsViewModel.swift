//
//  ProblemsViewModel.swift
//  traverse
//
//  Owns the deep solve payload for the Problems tab.
//
//  Home deliberately does *not* fetch this any more: the rows carry AI
//  analysis text, mistake tags and the full attempt history, which is the
//  heaviest thing the API returns and was being pulled on every pull-to-refresh
//  to feed two cards. This view model is where that cost now lives, and only
//  when the tab is actually opened.
//

import Foundation
import Combine

@MainActor
final class ProblemsViewModel: ObservableObject {
    @Published var solves: [Solve]?
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// The Problems tab is the one place that genuinely wants a long history:
    /// the solve list, the topic filter and the mistake-tag rollup all read
    /// from it.
    static let solveLimit = 200

    init() {
        // Seed from the shared persisted cache so the tab paints instantly and
        // only then goes to the network.
        if let cached = DataManager.shared.recentSolves, !cached.isEmpty {
            self.solves = cached
        }
    }

    func load(forceRefresh: Bool = false) async {
        if !forceRefresh, let existing = solves, !existing.isEmpty {
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let response = try await NetworkService.shared.getSolves(limit: Self.solveLimit)
            // Merges into the shared cache rather than replacing it, so the
            // home charts keep whatever deeper history has already accumulated.
            let merged = DataManager.shared.mergeAndPersistSolves(response.solves)

            await MainActor.run {
                self.solves = merged
                self.isLoading = false
            }
            print("[ProblemsViewModel] loaded \(response.solves.count) solves, merged total \(merged.count)")
        } catch let error where error is CancellationError {
            await MainActor.run { isLoading = false }
        } catch {
            print("[ProblemsViewModel] load FAILED: \(error)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}
