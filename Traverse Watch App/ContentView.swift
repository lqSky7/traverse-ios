//
//  ContentView.swift
//  Traverse Watch App
//
//  Created by ca5 on 02/04/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: WatchDataManager
    @State private var selectedPage = 0
    
    var body: some View {
        TabView(selection: $selectedPage) {
            // Page 1: Stats Dashboard
            StatsDashboardView()
                .tag(0)
            
            // Page 2: Achievements & Revisions
            AchievementsRevisionsPage()
                .tag(1)
            
            // Page 3: QR Code
            WatchQRCodePage()
                .tag(2)
        }
        .tabViewStyle(.verticalPage(transitionStyle: .blur))
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchDataManager.shared)
}
