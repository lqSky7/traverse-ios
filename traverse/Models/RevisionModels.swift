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
        ISO8601DateFormatter().date(from: scheduledFor) ?? Date()
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
