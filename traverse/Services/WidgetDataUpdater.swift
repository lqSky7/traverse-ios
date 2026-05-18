//
//  WidgetDataUpdater.swift
//  traverse
//
//  Updates shared widget data in App Group UserDefaults (for iOS widgets)
//  AND sends the same data to Apple Watch via WatchSyncManager.
//

import Foundation
import WidgetKit
import UIKit

class WidgetDataUpdater {
    static let shared = WidgetDataUpdater()
    
    private init() {}
    
    /// Current username for QR code sync to Watch
    var currentUsername: String? {
        didSet {
            // Regenerate QR when username changes
            if let username = currentUsername {
                cachedQRImageData = generateQRImageData(for: username)
                print("[WidgetDataUpdater] Generated QR for \(username), data size: \(cachedQRImageData?.count ?? 0) bytes")
            } else {
                cachedQRImageData = nil
            }
        }
    }
    
    /// Cached QR code image data for Watch sync
    private var cachedQRImageData: Data?
    
    /// Generate QR code image data for a username
    private func generateQRImageData(for username: String) -> Data? {
        guard let qrImage = QRCodeGenerator.shared.generateFriendQR(for: username, size: 200) else {
            print("[WidgetDataUpdater] Failed to generate QR image for \(username)")
            return nil
        }
        return qrImage.pngData()
    }
    
    /// Ensure QR is generated for current username
    private func ensureQRGenerated() -> Data? {
        if cachedQRImageData == nil, let username = currentUsername {
            cachedQRImageData = generateQRImageData(for: username)
        }
        return cachedQRImageData
    }
    
    func updateWidgetData(
        userStats: UserStatsData?,
        recentSolve: Solve?,
        revisions: [Revision]?,
        achievementStats: AchievementStatsData? = nil,
        solvedToday: Bool = false
    ) {
        // Ensure QR is generated before syncing
        let qrData = ensureQRGenerated()
        
        var widgetData = WidgetData(
            streak: nil,
            recentSolve: nil,
            revisions: nil,
            revisionsDueCount: 0,
            achievements: nil,
            username: currentUsername,
            qrCodeImageData: qrData,
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
                username: currentUsername,
                qrCodeImageData: qrData,
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
                username: currentUsername,
                qrCodeImageData: qrData,
                lastUpdated: widgetData.lastUpdated
            )
        }
        
        // Update revisions - just use what's passed, no filtering
        if let revs = revisions {
            let revisionDataArray = revs.map { revision in
                RevisionData(
                    id: revision.id,
                    problemTitle: revision.problem.title,
                    slug: revision.problem.slug,
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
                username: currentUsername,
                qrCodeImageData: qrData,
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
                username: currentUsername,
                qrCodeImageData: qrData,
                lastUpdated: widgetData.lastUpdated
            )
        }
        
        // Save to shared UserDefaults (for iOS widgets)
        WidgetDataManager.shared.saveWidgetData(widgetData)
        
        // Reload all iOS widgets
        WidgetCenter.shared.reloadAllTimelines()
        
        // Sync to Apple Watch
        WatchSyncManager.shared.syncWidgetData(widgetData)
    }
    
    func updateStreakStatus(solvedToday: Bool, currentStreak: Int, totalXp: Int, totalSolves: Int) {
        // Ensure QR is generated
        let qrData = ensureQRGenerated()
        
        // Load existing data
        var widgetData = WidgetDataManager.shared.loadWidgetData() ?? WidgetData(
            streak: nil,
            recentSolve: nil,
            revisions: nil,
            revisionsDueCount: 0,
            achievements: nil,
            username: currentUsername,
            qrCodeImageData: qrData,
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
            username: currentUsername,
            qrCodeImageData: qrData,
            lastUpdated: Date()
        )
        
        WidgetDataManager.shared.saveWidgetData(widgetData)
        WidgetCenter.shared.reloadTimelines(ofKind: "StreakWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "StreakLockScreenWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "MotivationalLockScreenWidget")
        
        // Sync to Apple Watch
        WatchSyncManager.shared.syncWidgetData(widgetData)
    }
}
