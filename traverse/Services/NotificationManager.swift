//
//  NotificationManager.swift
//  traverse
//

import Foundation
import UserNotifications

class NotificationManager: NSObject {
    static let shared = NotificationManager()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Request Authorization
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                print("Notification permission granted")
            } else {
                print("Notification permission denied")
            }
            return granted
        } catch {
            print("Error requesting notification authorization: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Check Authorization Status
    func checkAuthorizationStatus() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }
    
    // MARK: - Schedule Revision Notifications
    func scheduleRevisionNotifications(for revisions: [Revision]) async {
        // Remove all pending revision notifications first
        await removePendingRevisionNotifications()
        
        guard await checkAuthorizationStatus() else {
            print("Notifications not authorized")
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        for revision in revisions {
            // Skip completed revisions
            guard !revision.isCompleted else { continue }
            
            let scheduledDate = revision.scheduledDate
            
            // Skip past dates
            guard scheduledDate > now else { continue }
            
            // Schedule notification for 9 AM on the revision date
            var components = calendar.dateComponents([.year, .month, .day], from: scheduledDate)
            components.hour = 9
            components.minute = 0
            
            let content = UNMutableNotificationContent()
            content.title = "Revision Due Today"
            content.body = "Time to review: \(revision.problem.title)"
            content.sound = .default
            content.badge = 1
            content.categoryIdentifier = "REVISION"
            content.userInfo = [
                "revisionId": revision.id,
                "problemId": revision.problem.id,
                "type": "revision"
            ]
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "revision-\(revision.id)",
                content: content,
                trigger: trigger
            )
            
            do {
                try await UNUserNotificationCenter.current().add(request)
                print("Scheduled notification for revision \(revision.id) at \(components)")
            } catch {
                print("Error scheduling notification for revision \(revision.id): \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Schedule Daily Reminder
    func scheduleDailyRevisionReminder() async {
        guard await checkAuthorizationStatus() else {
            print("Notifications not authorized")
            return
        }
        
        // Remove existing daily reminder
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-revision-reminder"])
        
        // Schedule for 9 AM every day
        var components = DateComponents()
        components.hour = 9
        components.minute = 0
        
        let content = UNMutableNotificationContent()
        content.title = "Daily Revision Reminder"
        content.body = "Check your scheduled revisions for today"
        content.sound = .default
        content.categoryIdentifier = "REVISION_REMINDER"
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily-revision-reminder",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("Scheduled daily revision reminder")
        } catch {
            print("Error scheduling daily reminder: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Remove Pending Revision Notifications
    func removePendingRevisionNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pendingRequests = await center.pendingNotificationRequests()
        
        let revisionIdentifiers = pendingRequests
            .filter { $0.identifier.hasPrefix("revision-") }
            .map { $0.identifier }
        
        center.removePendingNotificationRequests(withIdentifiers: revisionIdentifiers)
        print("Removed \(revisionIdentifiers.count) pending revision notifications")
    }
    
    // MARK: - Remove All Notifications
    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        print("Removed all notifications")
    }
    
    // MARK: - Get Pending Notifications Count
    func getPendingNotificationsCount() async -> Int {
        let pendingRequests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return pendingRequests.count
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        if let type = userInfo["type"] as? String, type == "revision" {
            // Handle revision notification tap
            // You can post a notification to navigate to revisions tab
            NotificationCenter.default.post(name: NSNotification.Name("OpenRevisionsTab"), object: nil)
        }
        
        completionHandler()
    }
}
