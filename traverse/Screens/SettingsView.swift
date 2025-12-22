import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingEditProfile = false
    @State private var showingChangePassword = false
    @State private var showingDeleteAccount = false
    @State private var showingLogoutConfirmation = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Form {
                // User Profile Section
                if let user = authViewModel.currentUser {
                    Section {
                        VStack {
                            if let imageUrl = user.profileImageURL {
                                AsyncImage(url: URL(string: imageUrl)) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(width: 120, height: 120)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 120)
                                            .clipShape(Circle())
                                    case .failure:
                                        Image(systemName: "person.crop.circle.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 120, height: 120)
                                            .foregroundStyle(.blue)
                                    default:
                                        Image(systemName: "person.crop.circle.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 120, height: 120)
                                            .foregroundStyle(.blue)
                                    }
                                }
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 120, height: 120)
                                    .foregroundStyle(.blue)
                            }
                            
                            VStack(spacing: 4) {
                                Text(user.username)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                        
                        HStack {
                            Text("Streak")
                            Spacer()
                            Text("\(user.currentStreak) days")
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Total XP")
                            Spacer()
                            Text("\(user.totalXp)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Account Settings
                Section("Account") {
                    Button {
                        showingEditProfile = true
                    } label: {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Edit Profile")
                                .foregroundStyle(.primary)
                        }
                    }
                    
                    Button {
                        showingChangePassword = true
                    } label: {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.blue)
                            Text("Change Password")
                                .foregroundStyle(.primary)
                        }
                    }
                }
                
                // Danger Zone
                Section("Danger Zone") {
                    Button {
                        showingDeleteAccount = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundStyle(.red)
                            Text("Delete Account")
                        }
                        .foregroundStyle(.red)
                    }
                    
                    Button {
                        showingLogoutConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                                .foregroundStyle(.red)
                            Text("Logout")
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingEditProfile) {
                ProfileEditView()
                    .environmentObject(authViewModel)
            }
            .sheet(isPresented: $showingChangePassword) {
                ChangePasswordView()
                    .environmentObject(authViewModel)
            }
            .sheet(isPresented: $showingDeleteAccount) {
                DeleteAccountView()
                    .environmentObject(authViewModel)
            }
            .alert("Logout", isPresented: $showingLogoutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Logout", role: .destructive) {
                    Task {
                        await handleLogout()
                    }
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
            .disabled(isLoading)
        }
    }
    
    private func handleLogout() async {
        isLoading = true
        do {
            try await authViewModel.logout()
        } catch {
            // Error handled in view model
        }
        isLoading = false
    }
}
