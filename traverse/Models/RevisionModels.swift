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
    let solve: RevisionSolve
    
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
    
    var isOverdue: Bool {
        guard !isCompleted else { return false }
        return scheduledDate < Date()
    }
}

struct RevisionProblem: Codable {
    let id: Int
    let platform: String
    let slug: String
    let title: String
    let difficulty: String
}

struct RevisionSolve: Codable {
    let id: Int
    let xpAwarded: Int
    let solvedAt: String
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
    let overdue: Int
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
