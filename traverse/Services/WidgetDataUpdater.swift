//
//  WidgetDataUpdater.swift
//  traverse
//

import Foundation
import WidgetKit

class WidgetDataUpdater {
    static let shared = WidgetDataUpdater()
    
    private init() {}
    
    func updateWidgetData(
        userStats: UserStatsData?,
        recentSolve: Solve?,
        revisions: [Revision]?,
        achievementStats: AchievementStatsData? = nil,
        solvedToday: Bool = false
    ) {
        var widgetData = WidgetData(
            streak: nil,
            recentSolve: nil,
            revisions: nil,
            revisionsDueCount: 0,
            achievements: nil,
            lastUpdated: Date()
        )
        
        // Update streak data
        if let stats = userStats {
            widgetData = WidgetData(
                streak: StreakData(
                    currentStreak: stats.currentStreak,
                    solvedToday: solvedToday,
                    totalXp: stats.totalXp,
                    totalSolves: stats.totalSolves
                ),
                recentSolve: widgetData.recentSolve,
                revisions: widgetData.revisions,
                revisionsDueCount: widgetData.revisionsDueCount,
                achievements: widgetData.achievements,
                lastUpdated: widgetData.lastUpdated
            )
        }
        
        // Update recent solve
        if let solve = recentSolve {
            widgetData = WidgetData(
                streak: widgetData.streak,
                recentSolve: RecentSolveData(
                    problemTitle: solve.problem.title,
                    platform: solve.problem.platform,
                    difficulty: solve.problem.difficulty,
                    xpAwarded: solve.xpAwarded,
                    solvedAt: solve.solvedAt,
                    language: solve.submission.language
                ),
                revisions: widgetData.revisions,
                revisionsDueCount: widgetData.revisionsDueCount,
                achievements: widgetData.achievements,
                lastUpdated: widgetData.lastUpdated
            )
        }
        
        // Update revisions - just use what's passed, no filtering
        if let revs = revisions {
            let revisionDataArray = revs.map { revision in
                RevisionData(
                    id: revision.id,
                    problemTitle: revision.problem.title,
                    platform: revision.problem.platform,
                    difficulty: revision.problem.difficulty,
                    revisionNumber: revision.revisionNumber,
                    scheduledFor: revision.scheduledFor,
                    isOverdue: revision.isOverdue
                )
            }
            
            widgetData = WidgetData(
                streak: widgetData.streak,
                recentSolve: widgetData.recentSolve,
                revisions: revisionDataArray,
                revisionsDueCount: revs.count,  // Simple count - no datetime parsing
                achievements: widgetData.achievements,
                lastUpdated: widgetData.lastUpdated
            )
        }
        
        // Update achievements
        if let achievements = achievementStats {
            widgetData = WidgetData(
                streak: widgetData.streak,
                recentSolve: widgetData.recentSolve,
                revisions: widgetData.revisions,
                revisionsDueCount: widgetData.revisionsDueCount,
                achievements: AchievementsData(
                    unlocked: achievements.unlocked,
                    total: achievements.total
                ),
                lastUpdated: widgetData.lastUpdated
            )
        }
        
        // Save to shared UserDefaults
        WidgetDataManager.shared.saveWidgetData(widgetData)
        
        // Reload all widgets
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func updateStreakStatus(solvedToday: Bool, currentStreak: Int, totalXp: Int, totalSolves: Int) {
        // Load existing data
        var widgetData = WidgetDataManager.shared.loadWidgetData() ?? WidgetData(
            streak: nil,
            recentSolve: nil,
            revisions: nil,
            revisionsDueCount: 0,
            achievements: nil,
            lastUpdated: Date()
        )
        
        // Update only streak data
        widgetData = WidgetData(
            streak: StreakData(
                currentStreak: currentStreak,
                solvedToday: solvedToday,
                totalXp: totalXp,
                totalSolves: totalSolves
            ),
            recentSolve: widgetData.recentSolve,
            revisions: widgetData.revisions,
            revisionsDueCount: widgetData.revisionsDueCount,
            achievements: widgetData.achievements,
            lastUpdated: Date()
        )
        
        WidgetDataManager.shared.saveWidgetData(widgetData)
        WidgetCenter.shared.reloadTimelines(ofKind: "StreakWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "StreakLockScreenWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "MotivationalLockScreenWidget")
    }
}
