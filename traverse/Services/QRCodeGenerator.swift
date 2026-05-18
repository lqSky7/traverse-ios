//
//  QRCodeGenerator.swift
//  traverse
//
//  Generates stylish branded QR codes for friend sharing.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - QR Code Generator

class QRCodeGenerator {
    static let shared = QRCodeGenerator()
    
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()
    
    private init() {}
    
    /// Generates a basic QR code image from a string
    func generateQRCode(from string: String, size: CGFloat = 200) -> UIImage? {
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction for styling
        
        guard let ciImage = filter.outputImage else { return nil }
        
        // Scale the QR code to desired size
        let scaleX = size / ciImage.extent.size.width
        let scaleY = size / ciImage.extent.size.height
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    /// Creates a deep link URL for adding a friend
    func friendDeepLink(for username: String) -> String {
        return "traverse://add-friend/\(username)"
    }
    
    /// Generates a QR code UIImage for a username
    func generateFriendQR(for username: String, size: CGFloat = 200) -> UIImage? {
        let deepLink = friendDeepLink(for: username)
        return generateQRCode(from: deepLink, size: size)
    }
}

// MARK: - Stylish QR Code View

struct StylishQRCodeView: View {
    let username: String
    let size: CGFloat
    let showLabel: Bool
    
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    init(username: String, size: CGFloat = 200, showLabel: Bool = true) {
        self.username = username
        self.size = size
        self.showLabel = showLabel
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // QR Code with branded styling
            ZStack {
                // Outer glow
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                paletteManager.selectedPalette.primary.opacity(0.3),
                                paletteManager.selectedPalette.secondary.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: 20)
                    .frame(width: size + 40, height: size + 40)
                
                // QR container
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .frame(width: size + 32, height: size + 32)
                    
                    // QR Code
                    if let qrImage = QRCodeGenerator.shared.generateFriendQR(for: username, size: size) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: size, height: size)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                // Center logo overlay
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: size * 0.22, height: size * 0.22)
                                    
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    paletteManager.selectedPalette.primary,
                                                    paletteManager.selectedPalette.secondary
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: size * 0.18, height: size * 0.18)
                                    
                                    Image(systemName: "person.badge.plus")
                                        .font(.system(size: size * 0.08, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                    } else {
                        // Fallback
                        ProgressView()
                            .frame(width: size, height: size)
                    }
                    
                    // Corner accents
                    cornerAccents
                }
            }
            
            if showLabel {
                // Username label
                VStack(spacing: 4) {
                    Text("@\(username)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("Scan to add friend")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var cornerAccents: some View {
        let accentSize: CGFloat = 12
        let offset = (size + 32) / 2 - accentSize / 2 - 4
        
        return ZStack {
            // Top-left
            Circle()
                .fill(paletteManager.selectedPalette.primary)
                .frame(width: accentSize, height: accentSize)
                .offset(x: -offset, y: -offset)
            
            // Top-right
            Circle()
                .fill(paletteManager.selectedPalette.secondary)
                .frame(width: accentSize, height: accentSize)
                .offset(x: offset, y: -offset)
            
            // Bottom-left
            Circle()
                .fill(paletteManager.selectedPalette.secondary)
                .frame(width: accentSize, height: accentSize)
                .offset(x: -offset, y: offset)
            
            // Bottom-right
            Circle()
                .fill(paletteManager.selectedPalette.primary)
                .frame(width: accentSize, height: accentSize)
                .offset(x: offset, y: offset)
        }
    }
}

// MARK: - Compact QR for Watch

struct CompactQRCodeView: View {
    let username: String
    let size: CGFloat
    
    init(username: String, size: CGFloat = 120) {
        self.username = username
        self.size = size
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // White background for QR
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .frame(width: size + 16, height: size + 16)
                
                // QR Code
                if let qrImage = QRCodeGenerator.shared.generateFriendQR(for: username, size: size) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay {
                            // Small center dot
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: size * 0.15, height: size * 0.15)
                        }
                }
            }
            
            Text("@\(username)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Stylish QR") {
    ZStack {
        Color.black.ignoresSafeArea()
        StylishQRCodeView(username: "testuser", size: 200)
    }
}

#Preview("Compact QR") {
    ZStack {
        Color.black.ignoresSafeArea()
        CompactQRCodeView(username: "testuser", size: 120)
    }
}
