import SwiftUI

struct HomeTab: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Home")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("Your dashboard content will appear here")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .navigationTitle("Home")
        }
    }
}

struct ExploreTab: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Explore")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("Discover new content and features")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .navigationTitle("Explore")
        }
    }
}

struct ActivityTab: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Activity")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("Track your progress and achievements")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .navigationTitle("Activity")
        }
    }
}

#Preview("Home") {
    HomeTab()
}

#Preview("Explore") {
    ExploreTab()
}

#Preview("Activity") {
    ActivityTab()
}
