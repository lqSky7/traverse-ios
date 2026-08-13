//
//  TraverseApp.swift
//  Traverse Watch App
//
//  Created by ca5 on 02/04/26.
//

import SwiftUI
import WatchConnectivity
import WidgetKit

@main
struct Traverse_Watch_AppApp: App {
    // Initialize WatchDataManager early so WCSession activates on launch
    @StateObject private var dataManager = WatchDataManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
        }
    }
}
