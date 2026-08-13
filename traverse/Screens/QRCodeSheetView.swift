//
//  QRCodeSheetView.swift
//  traverse
//
//  Shows user's QR code for others to scan.
//

import SwiftUI

struct QRCodeSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    @State private var showShareSheet = false
    @State private var qrImage: UIImage?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(UIColor.systemBackground),
                        paletteManager.selectedPalette.primary.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    // QR Code
                    if let username = authViewModel.currentUser?.username {
                        StylishQRCodeView(username: username, size: 220)
                            .onAppear {
                                qrImage = QRCodeGenerator.shared.generateFriendQR(for: username, size: 400)
                                _ = WidgetDataUpdater.shared.prepareQRForFriendsPage(username: username)
                            }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            
                            Text("Not signed in")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Share button
                    if authViewModel.currentUser != nil {
                        Button(action: { showShareSheet = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.body.weight(.medium))
                                Text("Share QR Code")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [
                                        paletteManager.selectedPalette.primary,
                                        paletteManager.selectedPalette.secondary
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: Capsule()
                            )
                        }
                        .shadow(color: paletteManager.selectedPalette.primary.opacity(0.3), radius: 10, y: 4)
                    }
                    
                    Spacer().frame(height: 20)
                }
                .padding()
            }
            .navigationTitle("My QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = qrImage {
                    ShareSheet(items: [image])
                }
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    QRCodeSheetView()
        .environmentObject(AuthViewModel())
        .preferredColorScheme(.dark)
}
