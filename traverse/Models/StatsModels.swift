//
//  StatsModels.swift
//  traverse
//

import Foundation

// MARK: - User Statistics
struct UserStats: Codable {
    let username: String
    let stats: UserStatsData
}

struct UserStatsData: Codable {
    let currentStreak: Int
    let totalXp: Int
    let totalSolves: Int
    let totalSubmissions: Int
    let totalStreakDays: Int
    /// Longest unbroken run of active days. This is the figure the streak card
    /// labels "BEST" — `totalStreakDays` is a running total that keeps climbing
    /// across breaks, so it can never answer "what is my best streak".
    /// Optional because caches written by older builds predate the field.
    let longestStreak: Int?
    let problemsByDifficulty: ProblemsByDifficulty
    let availableFreezes: Int?
}


struct ProblemsByDifficulty: Codable {
    let easy: Int
    let medium: Int
    let hard: Int
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        easy = try container.decodeIfPresent(Int.self, forKey: .easy) ?? 0
        medium = try container.decodeIfPresent(Int.self, forKey: .medium) ?? 0
        hard = try container.decodeIfPresent(Int.self, forKey: .hard) ?? 0
    }
}

// MARK: - Submission Statistics
struct SubmissionStats: Codable {
    let stats: SubmissionStatsData
}

struct SubmissionStatsData: Codable {
    let total: Int
    let accepted: Int
    let failed: Int
    let acceptanceRate: String
    let languageBreakdown: [LanguageBreakdown]
}

struct LanguageBreakdown: Codable, Identifiable {
    var id: String { language }
    let language: String
    let count: Int
}

// MARK: - Solve Statistics
struct SolveStats: Codable {
    let stats: SolveStatsData
}

struct SolveStatsData: Codable {
    let totalSolves: Int
    let totalXp: Int
    let totalStreakDays: Int
    /// See `UserStatsData.longestStreak`.
    let longestStreak: Int?
    let byDifficulty: ProblemsByDifficulty
    let byPlatform: [String: Int]
}

// MARK: - Solves List
struct SolvesResponse: Codable {
    let solves: [Solve]
    let pagination: Pagination
}

struct CodeAttempt: Codable, Identifiable {
    var id: String { timestamp }
    let code: String?
    let language: String?
    let timestamp: String
    let type: String?
    let successful: Bool?
    let runNumber: Int?
    let submissionNumber: Int?
}

struct Solve: Codable, Identifiable {
    let id: Int
    let xpAwarded: Int
    let solvedAt: String
    /// Bumped by the backend on every later accepted submission for the same
    /// problem; `solvedAt` is stamped once and never moves. Optional because
    /// caches persisted by older builds of the app predate this field.
    let lastActivityAt: String?
    let aiAnalysis: String?
    let mistakeTags: [String]?
    let cognitiveTier: Int?
    let recallScore: Double?
    let attempts: [CodeAttempt]?
    let problem: Problem
    let submission: Submission
    let highlight: Highlight?
    
    var allAttempts: [CodeAttempt] {
        if let attempts = attempts, !attempts.isEmpty {
            return attempts
        }
        return submission.attempts ?? []
    }
}

struct Problem: Codable {
    let platform: String
    let slug: String
    let title: String
    let difficulty: String
    let category: Int?
    let topic: String?
    let subtopic: String?
    
    var displayTopic: String? {
        guard let topic = topic, !topic.isEmpty else { return nil }
        return formatTopicSlug(topic)
    }
}

public func formatTopicSlug(_ slug: String) -> String {
    let clean = slug.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !clean.isEmpty else { return "General" }
    
    let knownNames: [String: String] = [
        "kadanes-algorithm": "Kadane's Algorithm",
        "prefix-sum": "Prefix Sum",
        "prefix-sum-hashmap": "Prefix Sum + Hash Map",
        "sliding-window-fixed": "Sliding Window (Fixed)",
        "sliding-window-variable": "Sliding Window (Variable)",
        "two-pointers-opposite": "Two Pointers (Opposite)",
        "two-pointers-same": "Two Pointers (Same Direction)",
        "dutch-national-flag": "Dutch National Flag",
        "merge-intervals": "Merge Intervals",
        "cyclic-sort": "Cyclic Sort",
        "matrix-traversal": "Matrix Traversal",
        "general-arrays": "General Arrays",
        "string-matching": "String Matching",
        "palindrome": "Palindrome Logic",
        "anagram": "Anagram",
        "string-parsing": "String Parsing",
        "general-strings": "General Strings",
        "fast-slow-pointers": "Fast & Slow Pointers",
        "linked-list-reversal": "Linked List Reversal",
        "merge-lists": "Merge Linked Lists",
        "general-linked-list": "General Linked List",
        "tree-traversal": "Tree Traversal",
        "binary-search-tree": "Binary Search Tree",
        "tree-construction": "Tree Construction",
        "trie-prefix-tree": "Trie (Prefix Tree)",
        "segment-tree": "Segment Tree",
        "lowest-common-ancestor": "Lowest Common Ancestor",
        "general-trees": "General Trees",
        "bfs-shortest-path": "Graph BFS (Shortest Path)",
        "dfs-graph": "Graph DFS / Traversal",
        "topological-sort": "Topological Sort",
        "dijkstra": "Dijkstra's Algorithm",
        "bellman-ford": "Bellman-Ford",
        "union-find": "Disjoint Set / Union-Find",
        "minimum-spanning-tree": "Minimum Spanning Tree",
        "bipartite-check": "Bipartite Graph Check",
        "general-graphs": "General Graphs",
        "dp-1d-linear": "1D Linear DP",
        "dp-2d-grid": "2D Grid DP",
        "dp-knapsack": "0/1 Knapsack & Subset DP",
        "dp-lcs": "LCS / Edit Distance",
        "dp-lis": "Longest Increasing Subsequence",
        "dp-state-machine": "State Machine DP",
        "dp-interval": "Interval DP",
        "dp-tree": "Tree DP",
        "dp-bitmask": "Bitmask DP",
        "general-dp": "General DP",
        "activity-selection": "Activity Selection",
        "jump-game": "Jump Game Pattern",
        "task-scheduling": "Task Scheduling",
        "general-greedy": "General Greedy",
        "permutations": "Permutations",
        "combinations-subsets": "Combinations & Subsets",
        "constraint-satisfaction": "Constraint Satisfaction",
        "general-backtracking": "General Backtracking",
        "custom-comparator": "Custom Comparator Sorting",
        "counting-sort": "Counting Sort",
        "merge-sort-application": "Merge Sort Applications",
        "general-sorting": "General Sorting",
        "binary-search-standard": "Binary Search (Standard)",
        "binary-search-on-answer": "Binary Search on Answer",
        "binary-search-rotated": "Binary Search in Rotated Array",
        "general-searching": "General Binary Search",
        "monotonic-stack": "Monotonic Stack",
        "expression-evaluation": "Expression Evaluation",
        "parenthesis-matching": "Parentheses Matching",
        "general-stack": "General Stack",
        "sliding-window-deque": "Monotonic Deque",
        "bfs-queue": "Queue BFS",
        "general-queue": "General Queue",
        "top-k-elements": "Top K Elements",
        "merge-k-sorted": "Merge K Sorted Streams",
        "median-finding": "Two Heaps / Median Finding",
        "general-heap": "General Heap / PQ",
        "two-sum-pattern": "Two Sum / Pair Lookup",
        "frequency-counting": "Frequency Counting",
        "group-by-key": "Grouping by Key",
        "general-hashing": "General Hash Table",
        "bit-manipulation": "Bit Manipulation",
        "modular-arithmetic": "Modular Arithmetic",
        "gcd-lcm": "GCD & LCM",
        "prime-sieve": "Primes & Sieve",
        "general-math": "General Math"
    ]
    
    if let match = knownNames[clean.lowercased()] {
        return match
    }
    
    if clean.contains("-") {
        return clean
            .components(separatedBy: "-")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
    return clean
}

struct Submission: Codable {
    let language: String
    let happenedAt: String
    let aiAnalysis: String?
    let mistakeTags: [String]?
    let cognitiveTier: Int?
    let recallScore: Double?
    let numberOfTries: Int?
    let timeTaken: Int?
    let attempts: [CodeAttempt]?
}

/// The note a user attached to a solve.
///
/// `content` and `note` are optional on purpose: the server redacts them to
/// `null` when the viewer is not a friend, and a non-optional property would
/// turn that into a `keyNotFound` that fails the entire solve list rather than
/// just hiding the note.
struct Highlight: Codable {
    let id: Int
    let content: String?
    let note: String?
    let tags: [String]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    }

    init(id: Int, content: String?, note: String?, tags: [String]) {
        self.id = id
        self.content = content
        self.note = note
        self.tags = tags
    }

    /// True when the viewer is allowed to see anything on this note. False for a
    /// non-friend, whose payload carries the row with both text fields redacted.
    var hasContent: Bool {
        !(note ?? "").isEmpty || !(content ?? "").isEmpty || !tags.isEmpty
    }
}

struct Pagination: Codable {
    let total: Int
    let limit: Int
    let offset: Int
}

// MARK: - Achievement Statistics
struct AchievementStats: Codable {
    let stats: AchievementStatsData
}

struct AchievementStatsData: Codable {
    let total: Int
    let unlocked: Int
    let percentage: String
    let byCategory: [String: Int]
    /// Newest badge earned — drives the Awards card on the home feed.
    let latestAward: AchievementDetail?
}

// MARK: - All Achievements
struct AllAchievementsResponse: Codable {
    let achievements: [AchievementDetail]
    /// Award shelves (Close Your Rings, Monthly Challenges, …) with their badges attached.
    let sections: [AwardSection]?
    /// The challenge to lead with on the Awards hub — usually the running monthly challenge.
    let featured: AchievementDetail?
}

/// Numeric progress behind an award's ring. Absent for one-shot awards.
struct AwardProgress: Codable, Hashable {
    let current: Int
    let target: Int
    let unit: String

    /// "11 of 14 days"
    var caption: String { "\(current) of \(target) \(unit)" }
    var fraction: Double {
        guard target > 0 else { return 0 }
        return min(1, Double(current) / Double(target))
    }
}

struct AchievementDetail: Codable, Identifiable, Hashable {
    let id: Int
    let key: String
    let name: String
    let description: String
    let icon: String?
    let category: String
    let unlocked: Bool
    let unlockedAt: String?
    /// Award shelf id: rings | monthly | workouts | competitions | limited.
    let section: String?
    /// Artwork slug of the badge render in the Medals asset catalogue.
    let medal: String?
    let sortOrder: Int?
    let progress: AwardProgress?

    /// Resolved asset name, falling back to a stable pick so a badge always renders
    /// even if the server predates the medal catalogue.
    var medalAsset: String {
        if let medal, !medal.isEmpty { return medal }
        return MedalCatalog.fallback(for: key)
    }
}

/// One shelf of the Awards hub.
struct AwardSection: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let emptyCopy: String
    let unlocked: Int
    let total: Int
    let achievements: [AchievementDetail]

    /// The badge the shelf card leads with: the newest unlocked one, else whatever is
    /// closest to completion, else simply the first badge on the shelf.
    var hero: AchievementDetail? {
        if let newest = achievements
            .filter({ $0.unlocked })
            .sorted(by: { ($0.unlockedAt ?? "") > ($1.unlockedAt ?? "") })
            .first {
            return newest
        }
        if let closest = achievements
            .filter({ $0.progress != nil })
            .max(by: { ($0.progress?.fraction ?? 0) < ($1.progress?.fraction ?? 0) }) {
            return closest
        }
        return achievements.first
    }

    /// Small overlapping badges under the hero badge on the shelf card.
    var stack: [AchievementDetail] {
        Array(achievements.filter { $0.id != hero?.id }.prefix(3))
    }
}

// MARK: - Subscription Status
struct SubscriptionStatusResponse: Codable {
    let isSubscriptionActive: Bool
    let activeUntil: String?
    let planName: String?
    let canCancel: Bool?
    let cancellationScheduled: Bool?

    enum CodingKeys: String, CodingKey {
        case isSubscriptionActive, activeUntil, planName, canCancel, cancellationScheduled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isSubscriptionActive = try container.decodeIfPresent(Bool.self, forKey: .isSubscriptionActive) ?? false
        activeUntil = try container.decodeIfPresent(String.self, forKey: .activeUntil)
        planName = try container.decodeIfPresent(String.self, forKey: .planName)
        canCancel = try container.decodeIfPresent(Bool.self, forKey: .canCancel)
        cancellationScheduled = try container.decodeIfPresent(Bool.self, forKey: .cancellationScheduled)
    }
}

// MARK: - Freeze Models
struct FreezeInfoResponse: Codable {
    let availableFreezes: Int
    let usedFreezes: Int
    let totalFreezes: Int
    let latestGift: FreezeGiftInfo?
    let costs: FreezeCosts
}

struct FreezeGiftInfo: Codable {
    let id: Int
    let giftedBy: String?
    let createdAt: String
}

struct FreezeCosts: Codable {
    let purchase: Int
    let gift: Int
}

struct FreezePurchaseResponse: Codable {
    let message: String
    let freezesPurchased: Int
    let xpSpent: Int
    let availableFreezes: Int
    let remainingXp: Int
}

struct FreezeGiftResponse: Codable {
    let message: String
    let freezesGifted: Int
    let xpSpent: Int
    let recipient: String
    let remainingXp: Int
}

struct FreezeDatesResponse: Codable {
    let freezeDates: [String]
}

// MARK: - App Updates & Sync Response
struct AppUpdatesResponse: Codable {
    let achievements: [AchievementDetail]
    let friendRequests: [FriendRequest]
    let streakRequests: [FriendStreakRequest]
    let freezeInfo: FreezeInfoResponse
}
