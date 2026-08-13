//
//  FreezeShopSheet.swift
//  traverse
//

import SwiftUI
import Combine

@MainActor
class FreezeShopViewModel: ObservableObject {
    @Published var freezeInfo: FreezeInfoResponse? = nil
    @Published var isLoading = false
    @Published var isPurchasing = false
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil
    @Published var userXp: Int = 0
    
    func loadFreezeInfo() async {
        isLoading = true
        errorMessage = nil
        
        do {
            freezeInfo = try await NetworkService.shared.getFreezeInfo()
            if let info = freezeInfo {
                AchievementToastManager.shared.checkFreezeInfo(info, isUserPurchase: isPurchasing)
            }
            // Also get user XP from current user
            let user = try await NetworkService.shared.getCurrentUser()
            userXp = user.totalXp
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func purchaseFreeze(count: Int) async {
        isPurchasing = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let response = try await NetworkService.shared.purchaseFreezes(count: count)
            successMessage = response.message
            userXp = response.remainingXp
            // Reload freeze info
            await loadFreezeInfo()
            HapticManager.shared.success()
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.shared.error()
        }
        
        isPurchasing = false
    }
}

struct FreezeShopSheet: View {
    @StateObject private var viewModel = FreezeShopViewModel()
    @ObservedObject var paletteManager = ColorPaletteManager.shared
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedCount = 1
    @State private var showingInfo = false
    @Environment(\.dismiss) private var dismiss
    
    private var totalCost: Int {
        selectedCount * (viewModel.freezeInfo?.costs.purchase ?? 100)
    }
    
    private var canAfford: Bool {
        displayedXp >= totalCost
    }
    
    // Use cached XP initially, then switch to loaded value
    private var displayedXp: Int {
        if viewModel.userXp > 0 {
            return viewModel.userXp
        }
        return authViewModel.currentUser?.totalXp ?? 0
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Current Freezes Card - Glass Style
                    freezeStatusCard
                    
                    // Purchase Section
                    purchaseSection
                }
                .padding()
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Freeze Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadFreezeInfo()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("Success", isPresented: .constant(viewModel.successMessage != nil)) {
                Button("OK") {
                    viewModel.successMessage = nil
                }
            } message: {
                Text(viewModel.successMessage ?? "")
            }
        }
    }
    
    // MARK: - Freeze Status Card (Glass Style)
    private var freezeStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "snowflake")
                    .font(.system(size: 36))
                    .foregroundStyle(paletteManager.selectedPalette.primary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(viewModel.freezeInfo?.availableFreezes ?? 0)")
                        .font(.system(size: 32, weight: .bold))
                    
                    Text("Available Freezes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(displayedXp)")
                        .font(.title2.bold())
                        .foregroundStyle(paletteManager.selectedPalette.primary)
                    
                    Text("XP Balance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if let used = viewModel.freezeInfo?.usedFreezes, used > 0 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("\(used) freeze\(used == 1 ? "" : "s") used to save your streak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: paletteManager.selectedPalette.primary.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Purchase Section
    private var purchaseSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Purchase Freezes")
                    .font(.headline)
                
                Spacer()
                
                // Info Button
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showingInfo.toggle()
                    }
                    HapticManager.shared.selection()
                } label: {
                    Image(systemName: showingInfo ? "info.circle.fill" : "info.circle")
                        .font(.title3)
                        .foregroundStyle(paletteManager.selectedPalette.primary)
                }
            }
            
            // Expandable Info Section
            if showingInfo {
                VStack(alignment: .leading, spacing: 10) {
                    FreezeInfoRow(icon: "calendar.badge.clock", text: "Freezes are automatically used when you miss a day")
                    FreezeInfoRow(icon: "flame.fill", text: "Your streak is preserved instead of resetting to 0")
                    FreezeInfoRow(icon: "gift.fill", text: "Gift freezes to friends for 70 XP each")
                }
                .padding(12)
                .background(Color(UIColor.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Quantity Selector - Circle Buttons
            HStack(spacing: 16) {
                ForEach(1...5, id: \.self) { count in
                    circleQuantityButton(count: count)
                }
            }
            
            // Purchase Button
            Button {
                Task {
                    await viewModel.purchaseFreeze(count: selectedCount)
                }
            } label: {
                HStack {
                    if viewModel.isPurchasing {
                        ProgressView()
                    } else {
                        Image(systemName: "snowflake")
                        Text("Purchase for \(totalCost) XP")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(canAfford ? paletteManager.selectedPalette.primary : .gray)
            .disabled(!canAfford || viewModel.isPurchasing)
            
            if !canAfford {
                Text("Not enough XP. You need \(totalCost - displayedXp) more XP.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .background(Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // Circle quantity button without cost number
    private func circleQuantityButton(count: Int) -> some View {
        Button {
            selectedCount = count
            HapticManager.shared.selection()
        } label: {
            Text("\(count)")
                .font(.title2.bold())
                .frame(width: 52, height: 52)
                .background(
                    Circle()
                        .fill(selectedCount == count ? paletteManager.selectedPalette.primary.opacity(0.2) : Color(UIColor.systemGray5))
                )
                .overlay(
                    Circle()
                        .stroke(selectedCount == count ? paletteManager.selectedPalette.primary : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Freeze Info Row
private struct FreezeInfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(ColorPaletteManager.shared.selectedPalette.primary)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
    }
}

#Preview {
    FreezeShopSheet()
        .environmentObject(AuthViewModel())
}
