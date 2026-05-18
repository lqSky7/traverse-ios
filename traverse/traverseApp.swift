//
//  traverseApp.swift
//  traverse
//
//  Created by ca5 on 22/12/25.
//

import SwiftUI
import UserNotifications
import WidgetKit
import WatchConnectivity
import Combine

@main
struct traverseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) var scenePhase
    
    init() {
        // Activate WatchConnectivity session early
        WatchSyncManager.shared.activate()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    DeepLinkManager.shared.handle(url: url)
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                // Check streak reminder when app becomes active
                Task {
                    await DataManager.shared.checkAndScheduleStreakReminder()
                }
                
                // Refresh all widgets when app opens
                WidgetCenter.shared.reloadAllTimelines()
                
                // Push latest data to Watch when app becomes active
                if let widgetData = WidgetDataManager.shared.loadWidgetData() {
                    WatchSyncManager.shared.syncWidgetData(widgetData)
                }
            }
        }
    }
}

// MARK: - Deep Link Manager

class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()
    
    @Published var pendingFriendUsername: String?
    
    private init() {}
    
    func handle(url: URL) {
        // Handle traverse://add-friend/{username}
        guard url.scheme == "traverse" else { return }
        
        if url.host == "add-friend",
           let username = url.pathComponents.last,
           !username.isEmpty,
           username != "/" {
            // Post notification to show user profile
            pendingFriendUsername = username
            NotificationCenter.default.post(
                name: .deepLinkAddFriend,
                object: nil,
                userInfo: ["username": username]
            )
        }
    }
}

extension Notification.Name {
    static let deepLinkAddFriend = Notification.Name("deepLinkAddFriend")
}

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Persist data before app terminates
        Task { @MainActor in
            DataManager.shared.persistData()
        }
    }
}
