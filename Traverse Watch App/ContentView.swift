//
//  ContentView.swift
//  Traverse Watch App
//
//  Created by ca5 on 02/04/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: WatchDataManager
    
    var body: some View {
        NavigationStack {
            StatsDashboardView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchDataManager.shared)
}
