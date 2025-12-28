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
        revisions: [Revision]?
    ) {
        var widgetData = WidgetData(
            streak: nil,
            recentSolve: nil,
            revisions: nil,
            revisionsDueCount: 0,
            lastUpdated: Date()
        )
        
        // Update streak data
        if let stats = userStats {
            // Check if solved today by looking at recent solves
            let solvedToday = false // This will be updated from HomeView
            
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
            lastUpdated: Date()
        )
        
        WidgetDataManager.shared.saveWidgetData(widgetData)
        WidgetCenter.shared.reloadTimelines(ofKind: "StreakWidget")
    }
}
