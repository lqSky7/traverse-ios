//
//  UserSearchView.swift
//  traverse
//

import SwiftUI
import Combine

@MainActor
class UserSearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [UserBasic] = []
    @Published var isSearching = false
    @Published var errorMessage: String?
    
    private var searchTask: Task<Void, Never>?
    
    func search() {
        searchTask?.cancel()
        
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        
        searchTask = Task {
            isSearching = true
            errorMessage = nil
            
            try? await Task.sleep(nanoseconds: 300_000_000) // Debounce 300ms
            
            guard !Task.isCancelled else { return }
            
            do {
                let response = try await NetworkService.shared.searchUsers(query: searchText, limit: 20)
                if !Task.isCancelled {
                    searchResults = response.users
                }
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                    searchResults = []
                }
            }
            
            isSearching = false
        }
    }
}

struct UserSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = UserSearchViewModel()
    
    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.isSearching {
                    ProgressView()
                        .padding()
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text(error)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No users found")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else if viewModel.searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Search for users")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else {
                    List(viewModel.searchResults) { user in
                        NavigationLink(value: user.username) {
                            UserSearchRow(user: user)
                        }
                    }
                }
            }
            .navigationTitle("Search Users")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search by username")
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.search()
            }
            .navigationDestination(for: String.self) { username in
                UserProfileView(username: username)
            }
        }
    }
}

struct UserSearchRow: View {
    let user: UserBasic
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.purple.gradient)
                .frame(width: 44, height: 44)
                .overlay {
                    Text(user.username.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.username)
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Label("\(user.currentStreak)", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    
                    Label("\(user.totalXp) XP", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    UserSearchView()
}
