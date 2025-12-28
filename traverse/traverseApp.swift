//
//  traverseApp.swift
//  traverse
//
//  Created by ca5 on 22/12/25.
//

import SwiftUI
import UserNotifications

@main
struct traverseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                // Check streak reminder when app becomes active
                Task {
                    await DataManager.shared.checkAndScheduleStreakReminder()
                }
            }
        }
    }
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
