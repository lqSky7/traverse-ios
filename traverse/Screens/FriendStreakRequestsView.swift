//
//  FriendStreakRequestsView.swift
//  traverse
//

import SwiftUI
import Combine

@MainActor
class FriendStreakRequestsViewModel: ObservableObject {
    @Published var receivedRequests: [FriendStreakRequest] = []
    @Published var sentRequests: [FriendStreakRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var hasLoadedRequests = false
    
    func loadRequests(force: Bool = false) async {
        // Use cached data from DataManager if available and not forcing refresh
        if !force && DataManager.shared.receivedStreakRequests.isEmpty == false {
            receivedRequests = DataManager.shared.receivedStreakRequests
            sentRequests = DataManager.shared.sentStreakRequests
            hasLoadedRequests = true
            return
        }
        
        guard !hasLoadedRequests || force else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            async let received = NetworkService.shared.getReceivedFriendStreakRequests()
            async let sent = NetworkService.shared.getSentFriendStreakRequests()
            
            receivedRequests = try await received
            sentRequests = try await sent
            
            // Cache the data
            DataManager.shared.receivedStreakRequests = receivedRequests
            DataManager.shared.sentStreakRequests = sentRequests
            DataManager.shared.persistData()
            
            hasLoadedRequests = true
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func acceptRequest(_ request: FriendStreakRequest) async {
        do {
            try await NetworkService.shared.acceptFriendStreakRequest(requestId: request.id)
            await loadRequests(force: true)
            HapticManager.shared.success()
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.shared.error()
        }
    }
    
    func rejectRequest(_ request: FriendStreakRequest) async {
        do {
            try await NetworkService.shared.rejectFriendStreakRequest(requestId: request.id)
            await loadRequests(force: true)
            HapticManager.shared.success()
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.shared.error()
        }
    }
    
    func cancelRequest(_ request: FriendStreakRequest) async {
        do {
            try await NetworkService.shared.cancelFriendStreakRequest(requestId: request.id)
            await loadRequests(force: true)
            HapticManager.shared.success()
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.shared.error()
        }
    }
}

struct FriendStreakRequestsView: View {
    @ObservedObject var viewModel: FriendStreakRequestsViewModel
    @StateObject private var paletteManager = ColorPaletteManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.receivedRequests.isEmpty && viewModel.sentRequests.isEmpty {
                    emptyState
                } else {
                    requestsList
                }
            }
            .navigationTitle("Streak Requests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .refreshable {
                await viewModel.loadRequests()
            }
            .task {
                await viewModel.loadRequests()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "flame.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Streak Requests")
                .font(.headline)
            Text("Start a streak with a friend from their profile!")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    private var requestsList: some View {
        List {
            if !viewModel.receivedRequests.isEmpty {
                Section {
                    ForEach(viewModel.receivedRequests) { request in
                        ReceivedStreakRequestRow(
                            request: request,
                            onAccept: {
                                Task {
                                    await viewModel.acceptRequest(request)
                                }
                            },
                            onReject: {
                                Task {
                                    await viewModel.rejectRequest(request)
                                }
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    Text("Received")
                }
            }
            
            if !viewModel.sentRequests.isEmpty {
                Section {
                    ForEach(viewModel.sentRequests) { request in
                        SentStreakRequestRow(
                            request: request,
                            onCancel: {
                                Task {
                                    await viewModel.cancelRequest(request)
                                }
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    Text("Sent")
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Request Row Components

struct ReceivedStreakRequestRow: View {
    let request: FriendStreakRequest
    let onAccept: () -> Void
    let onReject: () -> Void
    @StateObject private var paletteManager = ColorPaletteManager.shared
    @State private var glowPhase: CGFloat = 0
    
    private var accentColor: Color {
        paletteManager.color(at: 0)
    }
    
    private var glowFillOpacity: Double {
        0.15 + 0.1 * (0.5 + 0.5 * sin(glowPhase))
    }
    
    private var glowStrokeOpacity: Double {
        0.4 + 0.2 * (0.5 + 0.5 * sin(glowPhase))
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Avatar with flame
                ZStack {
                    Circle()
                        .fill(accentColor.gradient)
                        .frame(width: 50, height: 50)
                        .overlay {
                            Text(request.requester?.username.prefix(1).uppercased() ?? "?")
                                .font(.title3)
                                .bold()
                                .foregroundStyle(.white)
                        }
                    
                    Image(systemName: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(accentColor)
                        .padding(6)
                        .background(.background)
                        .clipShape(Circle())
                        .offset(x: 18, y: 18)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.requester?.username ?? "Unknown")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("wants to start a streak")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if let streak = request.requester?.currentStreak, streak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                                .foregroundStyle(accentColor)
                            Text("\(streak) day streak")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Group {
                    Button {
                        onReject()
                    } label: {
                        HStack {
                            Image(systemName: "xmark")
                            Text("Decline")
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                    }
                    .tint(.red)
                }
                .applyGlassButtonStyle(.streakGlassProminent)
                
                Group {
                    Button {
                        onAccept()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Accept")
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                    }
                    .tint(accentColor)
                }
                .applyGlassButtonStyle(.streakGlassProminent)
            }
        }
        .padding(16)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [.clear, .clear, accentColor.opacity(glowFillOpacity)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .allowsHitTesting(false)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.clear, .clear, accentColor.opacity(glowStrokeOpacity)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2
                )
                .allowsHitTesting(false)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowPhase = .pi * 2
            }
        }
    }
}

struct SentStreakRequestRow: View {
    let request: FriendStreakRequest
    let onCancel: () -> Void
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(paletteManager.color(at: 1).gradient)
                .frame(width: 50, height: 50)
                .overlay {
                    Text(request.requested?.username.prefix(1).uppercased() ?? "?")
                        .font(.title3)
                        .bold()
                        .foregroundStyle(.white)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(request.requested?.username ?? "Unknown")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("Pending")
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Group {
                Button {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .tint(.red)
            }
            .applyGlassButtonStyle(.streakGlassProminent)
        }
        .padding(16)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Glass Button Style Extension
extension View {
    @ViewBuilder
    func applyGlassButtonStyle(_ style: StreakGlassButtonStyle) -> some View {
        if #available(iOS 26.0, *) {
            switch style {
            case .streakGlass:
                self.buttonStyle(.glass)
            case .streakGlassProminent:
                self.buttonStyle(.glassProminent)
            }
        } else {
            self.buttonStyle(.bordered)
        }
    }
}

enum StreakGlassButtonStyle {
    case streakGlass
    case streakGlassProminent
}

