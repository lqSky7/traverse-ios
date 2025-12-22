//
//  FriendRequestsView.swift
//  traverse
//

import SwiftUI

struct FriendRequestsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: FriendsViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Requests", selection: $selectedTab) {
                    Text("Received (\(viewModel.receivedRequests.count))").tag(0)
                    Text("Sent (\(viewModel.sentRequests.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if selectedTab == 0 {
                    receivedRequestsList
                } else {
                    sentRequestsList
                }
            }
            .navigationTitle("Friend Requests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var receivedRequestsList: some View {
        Group {
            if viewModel.receivedRequests.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No received requests")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.receivedRequests) { request in
                        if let requester = request.requester {
                            ReceivedRequestRow(request: request, requester: requester, viewModel: viewModel)
                        }
                    }
                }
            }
        }
    }
    
    private var sentRequestsList: some View {
        Group {
            if viewModel.sentRequests.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No sent requests")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.sentRequests) { request in
                        if let addressee = request.addressee {
                            SentRequestRow(request: request, addressee: addressee, viewModel: viewModel)
                        }
                    }
                }
            }
        }
    }
}

struct ReceivedRequestRow: View {
    let request: FriendRequest
    let requester: UserBasic
    @ObservedObject var viewModel: FriendsViewModel
    @State private var isProcessing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(.blue.gradient)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(requester.username.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(requester.username)
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        Label("\(requester.currentStreak)", systemImage: "flame.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        
                        Label("\(requester.totalXp) XP", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                    
                    Text(formatDate(request.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Group {
                    Button {
                        isProcessing = true
                        Task {
                            await viewModel.acceptRequest(request)
                            isProcessing = false
                        }
                    } label: {
                        Text("Accept")
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.white)
                    .disabled(isProcessing)
                }
                .applyButtonStyle(.glassProminent)
                
                Group {
                    Button {
                        isProcessing = true
                        Task {
                            await viewModel.rejectRequest(request)
                            isProcessing = false
                        }
                    } label: {
                        Text("Reject")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(Color(red: 1.0, green: 0.7, blue: 0.7))
                    .disabled(isProcessing)
                }
                .applyButtonStyle(.glass)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return "" }
        
        let displayFormatter = RelativeDateTimeFormatter()
        displayFormatter.unitsStyle = .full
        return displayFormatter.localizedString(for: date, relativeTo: Date())
    }
}

struct SentRequestRow: View {
    let request: FriendRequest
    let addressee: UserBasic
    @ObservedObject var viewModel: FriendsViewModel
    @State private var isProcessing = false
    @State private var showingCancelConfirmation = false
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.purple.gradient)
                .frame(width: 44, height: 44)
                .overlay {
                    Text(addressee.username.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(addressee.username)
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Label("\(addressee.currentStreak)", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    
                    Label("\(addressee.totalXp) XP", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("Pending • \(formatDate(request.createdAt))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                showingCancelConfirmation = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .disabled(isProcessing)
        }
        .padding(.vertical, 4)
        .confirmationDialog("Cancel Friend Request", isPresented: $showingCancelConfirmation) {
            Button("Cancel Request", role: .destructive) {
                isProcessing = true
                Task {
                    await viewModel.cancelRequest(request)
                    isProcessing = false
                }
            }
            Button("Keep Request", role: .cancel) {}
        } message: {
            Text("Are you sure you want to cancel the friend request to \(addressee.username)?")
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return "" }
        
        let displayFormatter = RelativeDateTimeFormatter()
        displayFormatter.unitsStyle = .abbreviated
        return displayFormatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - View Extension for Glass Button Styles
extension View {
    @ViewBuilder
    func applyButtonStyle(_ style: GlassButtonStyle) -> some View {
        if #available(iOS 26.0, *) {
            switch style {
            case .glass:
                self.buttonStyle(.glass)
            case .glassProminent:
                self.buttonStyle(.glassProminent)
            }
        } else {
            self.buttonStyle(.bordered)
        }
    }
}

enum GlassButtonStyle {
    case glass
    case glassProminent
}

#Preview {
    FriendRequestsView(viewModel: FriendsViewModel())
}
