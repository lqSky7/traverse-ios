//
//  RevisionModels.swift
//  traverse
//

import Foundation

// MARK: - Revision
struct Revision: Codable, Identifiable {
    let id: Int
    let solveId: Int
    let userId: Int
    let problemId: Int
    let revisionNumber: Int
    let scheduledFor: String
    let completedAt: String?
    let createdAt: String
    let problem: RevisionProblem
    let solve: RevisionSolve?
    
    var scheduledDate: Date {
        // Try multiple date formats since backend may return different formats
        let formatters: [DateFormatter] = {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            let isoBasic = ISO8601DateFormatter()
            isoBasic.formatOptions = [.withInternetDateTime]
            
            // Custom formatter for date-only format like "2024-12-28"
            let dateOnly = DateFormatter()
            dateOnly.dateFormat = "yyyy-MM-dd"
            dateOnly.timeZone = TimeZone(identifier: "UTC")
            
            // Full datetime with timezone
            let fullDateTime = DateFormatter()
            fullDateTime.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            fullDateTime.timeZone = TimeZone(identifier: "UTC")
            
            return [dateOnly, fullDateTime]
        }()
        
        // Try ISO8601 first (handles most cases)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: scheduledFor) {
            return date
        }
        
        // Try without fractional seconds
        let isoBasic = ISO8601DateFormatter()
        isoBasic.formatOptions = [.withInternetDateTime]
        if let date = isoBasic.date(from: scheduledFor) {
            return date
        }
        
        // Try other formats
        for formatter in formatters {
            if let date = formatter.date(from: scheduledFor) {
                return date
            }
        }
        
        return Date()
    }
    
    var completedDate: Date? {
        guard let completedAt = completedAt else { return nil }
        return ISO8601DateFormatter().date(from: completedAt)
    }
    
    var isCompleted: Bool {
        completedAt != nil
    }
}

struct RevisionProblem: Codable {
    let id: Int
    let platform: String
    let slug: String
    let title: String
    let difficulty: String
    let category: Int?
    let topic: String?
    let subtopic: String?
}

struct RevisionSolve: Codable {
    let id: Int
    let xpAwarded: Int
    let solvedAt: String
    let aiAnalysis: String?
    let mistakeTags: [String]?
    let attempts: [CodeAttempt]?
}

struct RevisionDetailsResponse: Codable {
    let revision: Revision
}

// MARK: - Revision Response
struct RevisionsResponse: Codable {
    let revisions: [Revision]
    let pagination: Pagination?
}

// MARK: - Grouped Revisions
struct GroupedRevisionsResponse: Codable {
    let groups: [RevisionGroup]
}

struct RevisionGroup: Codable, Identifiable {
    let date: String
    let revisions: [Revision]
    let count: Int
    
    var id: String { date }
    
    var displayDate: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date) ?? Date()
    }
}

// MARK: - Revision Stats
struct RevisionStatsResponse: Codable {
    let total: Int
    let completed: Int
    let dueToday: Int
    let completionRate: Int
}

// MARK: - Complete Revision Response
struct CompleteRevisionResponse: Codable {
    let message: String
    let revision: Revision
}

// MARK: - ML Revision Attempt
struct RevisionAttemptRequest: Codable {
    let outcome: Int // 0 = failed, 1 = success
    let numTries: Int
    let timeSpentMinutes: Double
}

struct RevisionAttemptResponse: Codable {
    let message: String
    let attempt: RevisionAttempt
    let prediction: MLPrediction
    let nextRevision: Revision?
}

struct RevisionAttempt: Codable {
    let id: Int
    let revisionId: Int
    let userId: Int
    let problemId: Int
    let attemptNumber: Int
    let daysSinceLastAttempt: Double
    let outcome: Int
    let numTries: Int
    let timeSpentMinutes: Double
    let attemptedAt: String
}

struct MLPrediction: Codable {
    let nextReviewIntervalDays: Double
    let confidence: String
    
    enum CodingKeys: String, CodingKey {
        case nextReviewIntervalDays = "next_review_interval_days"
        case confidence
    }
}

// MARK: - ML Revision Daily Load
struct RevisionTodayResponse: Codable {
    let revisions: [Revision]
    let total: Int
    let maxDaily: Int
    let overflow: Int
    let isPaused: Bool?
    let pausedUntil: String?
}

// MARK: - Pause / Resume Models
struct PauseRevisionsRequest: Codable {
    let pauseDays: Int
}

struct PauseRevisionsResponse: Codable {
    let message: String
    let pausedUntil: String
    let isPaused: Bool
}

struct ResumeRevisionsRequest: Codable {
    let backlogDays: Int
}

struct ResumeRevisionsResponse: Codable {
    let message: String
    let rescheduled: Int
    let backlogDays: Int
    let isPaused: Bool
}


// MARK: - Revision Analytics
struct RevisionAnalyticsResponse: Codable {
    let overview: RevisionAnalyticsOverview
    let stabilityDistribution: RevisionStabilityDistribution
    let topicBreakdown: [RevisionTopicMetric]
    let weeklyCompletion: [WeeklyCompletion]
    let retentionHeatmap: [RevisionRetentionItem]
    let streaks: RevisionAnalyticsStreaks

    enum CodingKeys: String, CodingKey {
        case overview
        case stabilityDistribution
        case topicBreakdown
        case weeklyCompletion
        case retentionHeatmap
        case streaks
    }

    init(
        overview: RevisionAnalyticsOverview,
        stabilityDistribution: RevisionStabilityDistribution,
        topicBreakdown: [RevisionTopicMetric],
        weeklyCompletion: [WeeklyCompletion],
        retentionHeatmap: [RevisionRetentionItem],
        streaks: RevisionAnalyticsStreaks
    ) {
        self.overview = overview
        self.stabilityDistribution = stabilityDistribution
        self.topicBreakdown = topicBreakdown
        self.weeklyCompletion = weeklyCompletion
        self.retentionHeatmap = retentionHeatmap
        self.streaks = streaks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.overview = try container.decode(RevisionAnalyticsOverview.self, forKey: .overview)
        self.stabilityDistribution = try container.decode(RevisionStabilityDistribution.self, forKey: .stabilityDistribution)
        self.topicBreakdown = try container.decodeIfPresent([RevisionTopicMetric].self, forKey: .topicBreakdown) ?? []
        self.weeklyCompletion = try container.decodeIfPresent([WeeklyCompletion].self, forKey: .weeklyCompletion) ?? []
        self.retentionHeatmap = try container.decodeIfPresent([RevisionRetentionItem].self, forKey: .retentionHeatmap) ?? []
        self.streaks = try container.decode(RevisionAnalyticsStreaks.self, forKey: .streaks)
    }
}

struct RevisionAnalyticsOverview: Codable {
    let totalProblemsTracked: Int
    let masteredProblems: Int
    let leechProblems: Int
    let averageStability: Double
    let averageRetrievability: Double
}

struct RevisionStabilityDistribution: Codable {
    let critical: Int
    let weak: Int
    let developing: Int
    let strong: Int
    let mastered: Int
}

struct RevisionTopicMetric: Codable, Identifiable {
    var id: String { topic }
    let topic: String
    let problemCount: Int
    let averageRetention: Double
    let averageStability: Double
    let averageTimeMinutes: Double
}

struct WeeklyCompletion: Codable, Identifiable {
    var id: String { week }
    let week: String
    let count: Int
}

struct RevisionRetentionItem: Codable, Identifiable {
    var id: Int { problemId }
    let problemId: Int
    let problemTitle: String
    let problemSlug: String
    let platform: String
    let difficulty: String
    let retrievability: Double
    let stability: Double
    let difficulty_D: Double
    let lapses: Int
    let lastReviewAt: String?
    let isLeech: Bool
}

struct RevisionAnalyticsStreaks: Codable {
    let totalRevisionsCompleted: Int
}

