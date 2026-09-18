import Foundation

/// A day's ring state, as the server computes it.
///
/// Two rings, not one: `solves` counts problems solved for the first time today
/// and `revisions` counts reviews completed today. Keeping them separate is the
/// whole reason there are two — a day spent only reviewing is a different day
/// from one spent only solving, and a single combined ring would score them the
/// same.
///
/// Every field is optional-on-decode. The card is drawn on every launch and the
/// values come from a cache that may predate any given field, so a decode
/// failure here would blank the streak hero rather than degrade one number.
struct RingProgress: Codable, Equatable {
    /// Local date key, `YYYY-MM-DD`, in the user's own timezone.
    let date: String
    let solves: Int
    let revisions: Int

    /// The goals *today's* rings are measured against. These are the values the
    /// day was opened with, so they can differ from `configuredGoals` after the
    /// user edits the goals mid-day — a change applies from tomorrow.
    let solveGoal: Int
    let revisionGoal: Int

    /// What the user has actually set, which is what the customise sheet must
    /// show. Defaulted rather than required so an older cache still decodes.
    let configuredSolveGoal: Int
    let configuredRevisionGoal: Int

    let solveRingClosed: Bool
    let revisionRingClosed: Bool
    let allClosed: Bool
    let closedAt: String?

    enum CodingKeys: String, CodingKey {
        case date, solves, revisions, solveGoal, revisionGoal
        case configuredGoals, solveRingClosed, revisionRingClosed, allClosed, closedAt
    }

    private struct Goals: Codable {
        let solveGoal: Int
        let revisionGoal: Int
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        date = try c.decodeIfPresent(String.self, forKey: .date) ?? Self.todayKey()
        solves = try c.decodeIfPresent(Int.self, forKey: .solves) ?? 0
        revisions = try c.decodeIfPresent(Int.self, forKey: .revisions) ?? 0
        solveGoal = try c.decodeIfPresent(Int.self, forKey: .solveGoal) ?? 1
        revisionGoal = try c.decodeIfPresent(Int.self, forKey: .revisionGoal) ?? 1

        // `configuredGoals` is the source of truth for the sheet. When it is
        // absent (an older server, or a cache written before this field) the
        // day's own goals are the best available answer.
        let configured = try c.decodeIfPresent(Goals.self, forKey: .configuredGoals)
        configuredSolveGoal = configured?.solveGoal ?? solveGoal
        configuredRevisionGoal = configured?.revisionGoal ?? revisionGoal

        solveRingClosed = try c.decodeIfPresent(Bool.self, forKey: .solveRingClosed) ?? false
        revisionRingClosed = try c.decodeIfPresent(Bool.self, forKey: .revisionRingClosed) ?? false
        allClosed = try c.decodeIfPresent(Bool.self, forKey: .allClosed) ?? false
        closedAt = try c.decodeIfPresent(String.self, forKey: .closedAt)
    }

    init(
        date: String,
        solves: Int,
        revisions: Int,
        solveGoal: Int,
        revisionGoal: Int,
        configuredSolveGoal: Int,
        configuredRevisionGoal: Int,
        solveRingClosed: Bool,
        revisionRingClosed: Bool,
        allClosed: Bool,
        closedAt: String?
    ) {
        self.date = date
        self.solves = solves
        self.revisions = revisions
        self.solveGoal = solveGoal
        self.revisionGoal = revisionGoal
        self.configuredSolveGoal = configuredSolveGoal
        self.configuredRevisionGoal = configuredRevisionGoal
        self.solveRingClosed = solveRingClosed
        self.revisionRingClosed = revisionRingClosed
        self.allClosed = allClosed
        self.closedAt = closedAt
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(date, forKey: .date)
        try c.encode(solves, forKey: .solves)
        try c.encode(revisions, forKey: .revisions)
        try c.encode(solveGoal, forKey: .solveGoal)
        try c.encode(revisionGoal, forKey: .revisionGoal)
        try c.encode(
            Goals(solveGoal: configuredSolveGoal, revisionGoal: configuredRevisionGoal),
            forKey: .configuredGoals
        )
        try c.encode(solveRingClosed, forKey: .solveRingClosed)
        try c.encode(revisionRingClosed, forKey: .revisionRingClosed)
        try c.encode(allClosed, forKey: .allClosed)
        try c.encodeIfPresent(closedAt, forKey: .closedAt)
    }

    /// A day with nothing done yet, used before the first fetch resolves so the
    /// card has something to draw instead of an empty ring frame.
    static func empty(goals: RingGoals = .default) -> RingProgress {
        RingProgress(
            date: todayKey(),
            solves: 0,
            revisions: 0,
            solveGoal: goals.solveGoal,
            revisionGoal: goals.revisionGoal,
            configuredSolveGoal: goals.solveGoal,
            configuredRevisionGoal: goals.revisionGoal,
            solveRingClosed: false,
            revisionRingClosed: false,
            allClosed: false,
            closedAt: nil
        )
    }

    private static func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = Calendar(identifier: .gregorian)
        return f.string(from: Date())
    }

    /// Fraction of the solve ring that is filled, clamped to 1.
    ///
    /// Clamped because the ring is a goal, not a gauge: the fiftieth solve on a
    /// goal of five should close the ring, not overflow it. The raw count is
    /// still available for the legend.
    var solveFraction: Double {
        guard solveGoal > 0 else { return 0 }
        return min(Double(solves) / Double(solveGoal), 1)
    }

    var revisionFraction: Double {
        guard revisionGoal > 0 else { return 0 }
        return min(Double(revisions) / Double(revisionGoal), 1)
    }
}

/// The two goal values. Bounds mirror the server's (`MIN_RING_GOAL` /
/// `MAX_RING_GOAL`) so the stepper cannot offer a value the API will reject.
struct RingGoals: Codable, Equatable {
    var solveGoal: Int
    var revisionGoal: Int

    static let minimum = 1
    static let maximum = 50
    static let `default` = RingGoals(solveGoal: 1, revisionGoal: 1)

    func clamped() -> RingGoals {
        RingGoals(
            solveGoal: min(max(solveGoal, Self.minimum), Self.maximum),
            revisionGoal: min(max(revisionGoal, Self.minimum), Self.maximum)
        )
    }
}
