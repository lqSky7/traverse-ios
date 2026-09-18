import Foundation
import Combine
import SwiftUI

/// Today's rings, kept in sync between the server and the device.
///
/// Both copies are needed and they do different jobs. The server copy is
/// authoritative and is what makes the goals follow the user across devices. The
/// device copy exists so the streak card can draw real rings on the first frame
/// after launch — waiting for the network would leave the hero card showing
/// empty rings every cold start, which reads as "you did nothing today" for as
/// long as the request takes.
///
/// The two are reconciled on every successful fetch, and a fetch is triggered
/// after any action that can close a ring, so the server stays the tiebreaker.
@MainActor
final class RingsManager: ObservableObject {
    static let shared = RingsManager()

    /// Today's rings. Seeded from the cache, replaced by the server.
    @Published private(set) var progress: RingProgress

    /// The goals the sheet edits. Kept separate from `progress` because the
    /// sheet must show what the user *set*, which can differ from the goals
    /// today is being measured against after a mid-day change.
    @Published private(set) var goals: RingGoals

    /// Set when a save fails, so the sheet can say so and revert its optimistic
    /// edit rather than silently pretending the change stuck.
    @Published var saveError: String?

    private let cacheKey = "ringProgressCache"
    private let goalsKey = "ringGoalsCache"
    private var isFetching = false

    private init() {
        let cachedGoals: RingGoals = Self.readCache(key: goalsKey) ?? .default
        goals = cachedGoals

        if let cached: RingProgress = Self.readCache(key: cacheKey) {
            // A cache from a previous day must not be shown as today's progress.
            // The goals survive the rollover; the counts do not.
            progress = cached.date == Self.todayKey()
                ? cached
                : RingProgress.empty(goals: cachedGoals)
        } else {
            progress = RingProgress.empty(goals: cachedGoals)
        }
    }

    // MARK: - Reading

    /// Refreshes from the server. Safe to call on every appearance: overlapping
    /// calls are dropped rather than queued, because the only thing an extra
    /// fetch can do is return the same numbers again.
    func refresh() async {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }

        do {
            let rings = try await NetworkService.shared.getRings()
            apply(rings)
        } catch {
            // Deliberately silent. The cached values are still on screen and are
            // usually right; surfacing a network error on the home feed for a
            // decoration would be worse than showing slightly stale rings.
            print("[Rings] refresh failed: \(error.localizedDescription)")
        }
    }

    /// Re-reads the rings after an action that can close one.
    ///
    /// Called from the solve and revision completion paths. The server has
    /// already recomputed the day by the time this runs — the ring bookkeeping
    /// hangs off the same hook that records the streak — so this is a read, not
    /// a recompute.
    func refreshAfterActivity() async {
        await refresh()
    }

    // MARK: - Writing

    /// Saves new goals and adopts the server's recomputed view of today.
    ///
    /// Optimistic: the local values change first so the card and the sheet
    /// respond immediately, then the server's answer replaces them. The server
    /// decides whether a change applies today or from tomorrow, so its response
    /// is what is finally stored — the optimistic value is only a placeholder.
    func updateGoals(solveGoal: Int, revisionGoal: Int) async {
        let proposed = RingGoals(solveGoal: solveGoal, revisionGoal: revisionGoal).clamped()
        let previous = goals

        goals = proposed
        saveError = nil

        do {
            let result = try await NetworkService.shared.updateRingGoals(proposed)
            goals = result.goals
            apply(result.rings)
        } catch {
            goals = previous
            saveError = error.localizedDescription
            print("[Rings] goal save failed: \(error.localizedDescription)")
        }
    }

    /// Applies a server response and persists it.
    ///
    /// The goals cache is written from `configuredGoals` rather than the day's
    /// effective goals — caching the latter would make a mid-day change appear
    /// to have been lost on the next launch.
    private func apply(_ rings: RingProgress) {
        progress = rings

        let configured = RingGoals(
            solveGoal: rings.configuredSolveGoal,
            revisionGoal: rings.configuredRevisionGoal
        ).clamped()
        goals = configured

        Self.writeCache(rings, key: cacheKey)
        Self.writeCache(configured, key: goalsKey)
    }

    // MARK: - Cache

    private static func readCache<T: Decodable>(key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func writeCache<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    /// Clears the device copies. Called on sign-out so the next account does not
    /// briefly see the previous user's rings.
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: goalsKey)
        goals = .default
        progress = .empty()
    }

    private static func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = Calendar(identifier: .gregorian)
        return f.string(from: Date())
    }
}
