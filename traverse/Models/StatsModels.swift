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

struct Highlight: Codable {
    let id: Int
    let content: String
    let note: String
    let tags: [String]
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
}

// MARK: - All Achievements
struct AllAchievementsResponse: Codable {
    let achievements: [AchievementDetail]
}

struct AchievementDetail: Codable, Identifiable {
    let id: Int
    let key: String
    let name: String
    let description: String
    let icon: String?
    let category: String
    let unlocked: Bool
    let unlockedAt: String?
}

// MARK: - Subscription Status
struct SubscriptionStatusResponse: Codable {
    let isSubscriptionActive: Bool
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
