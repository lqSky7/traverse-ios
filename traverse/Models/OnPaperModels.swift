//
//  OnPaperModels.swift
//  traverse
//
//  Canonical Swift Codable models for OnPaper interview readiness platform
//

import Foundation

public struct OnPaperProject: Codable, Identifiable {
    public var id: String { projectId }
    public let projectId: String
    public let displayName: String
    public let rootFingerprint: String
    public let primaryLanguages: [String]
    public let frameworks: [String]
    public let gitAvailable: Bool
    public let curriculumStatus: String
    public let skillVersion: String
    public let schemaVersion: Int
    public let createdAt: String
    public let lastOpenedAt: String
}

public struct OnPaperSession: Codable, Identifiable {
    public var id: String { sessionId }
    public let sessionId: String
    public let projectId: String
    public let unitId: String?
    public let adapterType: String
    public let state: String
    public let startedAt: String
    public let endedAt: String?
    public let durationSeconds: Int
    public let summary: String?
    public let syncStatus: String
}

public struct OnPaperLearningUnit: Codable, Identifiable {
    public var id: String { unitId }
    public let unitId: String
    public let projectId: String
    public let title: String
    public let fileIds: [String]
    public let fileFingerprints: [String: String]
    public let conceptIds: [String]
    public let prerequisiteIds: [String]
    public let objectives: [String]
    public let selectionReason: String
    public let curriculumPosition: Int
    public let difficulty: Double
    public let status: String
    public let createdAt: String
    public let completedAt: String?
}

public struct OnPaperRubricCriterion: Codable, Identifiable {
    public var id: String
    public let name: String
    public let maxPoints: Int
    public let description: String
}

public struct OnPaperRubric: Codable {
    public let version: String
    public let criteria: [OnPaperRubricCriterion]
}

public struct OnPaperQuestion: Codable, Identifiable {
    public var id: String { questionId }
    public let questionId: String
    public let questionFamilyId: String
    public let unitId: String
    public let conceptIds: [String]
    public let category: String
    public let difficulty: Double
    public let prompt: String
    public let expectedAnswer: String
    public let rubric: OnPaperRubric
    public let askedAt: String
}

public struct OnPaperCriterionResult: Codable {
    public let criterionId: String
    public let availablePoints: Int
    public let awardedPoints: Int
    public let expectedElements: [String]
    public let mentionedElements: [String]
    public let missingElements: [String]
    public let incorrectClaims: [String]
    public let misconceptions: [String]
}

public struct OnPaperQuestionAttempt: Codable, Identifiable {
    public var id: String { attemptId }
    public let attemptId: String
    public let questionId: String
    public let sessionId: String
    public let studentAnswer: String
    public let score: Double
    public let criterionResults: [OnPaperCriterionResult]
    public let feedback: String
    public let misconceptionTags: [String]
    public let confidence: Double
    public let answeredAt: String
}

public struct OnPaperMistake: Codable, Identifiable {
    public var id: String { mistakeId }
    public let mistakeId: String
    public let canonicalKey: String
    public let title: String
    public let category: String
    public let conceptIds: [String]
    public let severity: String
    public let status: String
    public let firstSeenAt: String
    public let lastSeenAt: String
    public let occurrenceCount: Int
    public let resolvedCount: Int
    public let exampleAttemptIds: [String]
    public let fsrsCardIds: [String]
}

public struct OnPaperFSRSCard: Codable, Identifiable {
    public var id: String { cardId }
    public let cardId: String
    public let conceptId: String?
    public let mistakeId: String?
    public let questionFamilyId: String?
    public let prompt: String?
    public let explanation: String?
    public let userAnswer: String?
    public let keyTakeaway: String?
    public let state: String
    public let dueAt: String
    public let lastReviewAt: String?
    public let stability: Double
    public let difficulty: Double
    public let reps: Int
    public let lapses: Int
    public let scheduledDays: Double
    public let elapsedDays: Double
    public let algorithmVersion: String
    public let parameterVersion: String
    public let stateVersion: Int
}

public struct OnPaperProgressSummary: Codable {
    public let totalSessions: Int
    public let activeMistakesCount: Int
    public let resolvedMistakesCount: Int
    public let dueReviewsCount: Int
    public let currentStreak: Int
    public let streakQualifiedToday: Bool
}

public struct OnPaperUserPreferences: Codable {
    public let timezone: String
    public let dailyGoalType: String
    public let dailyGoalTarget: Int
    public let reminderTime: String
    public let quietHoursStart: String
    public let quietHoursEnd: String
    public let notificationsEnabled: Bool
}
