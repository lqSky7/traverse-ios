//
//  WatchQRCodePage.swift
//  Traverse Watch App
//
//  Page 3: Permanent stylish QR code for friend sharing.
//  QR image is pre-generated on iPhone and synced via WatchConnectivity.
//

import SwiftUI

private let cardBackground = Color(white: 0.11)
private let cardRadius: CGFloat = 14

struct WatchQRCodePage: View {
    @ObservedObject var dataManager = WatchDataManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Page indicator
                HStack(spacing: 4) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 10))
                        .foregroundStyle(.cyan)
                    Text("Add Friend")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
                .padding(.top, 4)
                
                // QR Code card
                qrCodeCard
                
                // Instructions
                instructionsCard
            }
            .padding(.horizontal, 2)
        }
    }
    
    // MARK: - QR Code Card
    
    private var qrCodeCard: some View {
        VStack(spacing: 8) {
            if let username = dataManager.username,
               let qrImageData = dataManager.qrCodeImageData,
               let uiImage = UIImage(data: qrImageData) {
                // Pre-generated QR from iPhone
                WatchStylishQRView(qrImage: uiImage, size: 100)
                
                // Username
                Text("@\(username)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            } else if let username = dataManager.username {
                // Username available but no QR yet
                VStack(spacing: 8) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.secondary)
                    
                    Text("@\(username)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("Syncing QR...")
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 16)
            } else {
                // Not synced state
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.secondary)
                    
                    Text("Sync Required")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    
                    Text("Open Traverse on iPhone")
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 16)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(cardBackground)
        )
    }
    
    // MARK: - Instructions Card
    
    private var instructionsCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "viewfinder")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.blue)
            
            Text("Show this to friends to let them scan and add you")
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(cardBackground)
        )
    }
}

// MARK: - Watch Stylish QR View

struct WatchStylishQRView: View {
    let qrImage: UIImage
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // White background for QR
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .frame(width: size + 16, height: size + 16)
            
            // QR Code
            Image(uiImage: qrImage)
                .interpolation(.none)
                .resizable()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay {
                    // Center gradient dot
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: size * 0.2, height: size * 0.2)
                        
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: size * 0.16, height: size * 0.16)
                        
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: size * 0.06, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            
            // Corner accents
            cornerAccents
        }
    }
    
    private var cornerAccents: some View {
        let accentSize: CGFloat = 6
        let offset = (size + 16) / 2 - accentSize / 2 - 2
        
        return ZStack {
            Circle()
                .fill(Color.blue)
                .frame(width: accentSize, height: accentSize)
                .offset(x: -offset, y: -offset)
            
            Circle()
                .fill(Color.purple)
                .frame(width: accentSize, height: accentSize)
                .offset(x: offset, y: -offset)
            
            Circle()
                .fill(Color.purple)
                .frame(width: accentSize, height: accentSize)
                .offset(x: -offset, y: offset)
            
            Circle()
                .fill(Color.blue)
                .frame(width: accentSize, height: accentSize)
                .offset(x: offset, y: offset)
        }
    }
}

#Preview {
    WatchQRCodePage()
}
