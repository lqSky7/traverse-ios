//
//  QRScannerView.swift
//  traverse
//
//  Camera-based QR code scanner for adding friends.
//

import SwiftUI
import AVFoundation

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var paletteManager = ColorPaletteManager.shared
    
    @State private var scannedUsername: String?
    @State private var showUserProfile = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isProcessing = false
    @State private var hasPermission = false
    @State private var permissionDenied = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if permissionDenied {
                    permissionDeniedView
                } else if hasPermission {
                    scannerView
                } else {
                    requestingPermissionView
                }
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarScrollMinimization()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                checkCameraPermission()
            }
            .sheet(isPresented: $showUserProfile) {
                if let username = scannedUsername {
                    UserProfileView(username: username)
                        .environmentObject(authViewModel)
                }
            }
            .alert("Invalid QR Code", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Scanner View
    
    private var scannerView: some View {
        ZStack {
            // Camera view
            CameraPreviewView(onCodeScanned: handleScannedCode)
                .ignoresSafeArea()
            
            // Overlay
            VStack {
                Spacer()
                
                // Scanning frame
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    paletteManager.selectedPalette.primary,
                                    paletteManager.selectedPalette.secondary
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 250, height: 250)
                    
                    // Corner accents
                    scannerCorners
                }
                
                Spacer()
                
                // Instructions
                VStack(spacing: 8) {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                        Text("Processing...")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.title2)
                            .foregroundStyle(.white)
                        Text("Point at a Traverse QR code")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.bottom, 40)
            }
        }
    }
    
    private var scannerCorners: some View {
        let cornerLength: CGFloat = 30
        let cornerWidth: CGFloat = 4
        let frameSize: CGFloat = 250
        let offset = frameSize / 2 - cornerLength / 2
        
        return ZStack {
            ForEach(0..<4) { index in
                CornerShape()
                    .stroke(paletteManager.selectedPalette.primary, lineWidth: cornerWidth)
                    .frame(width: cornerLength, height: cornerLength)
                    .rotationEffect(.degrees(Double(index) * 90))
                    .offset(
                        x: index == 0 || index == 3 ? -offset : offset,
                        y: index == 0 || index == 1 ? -offset : offset
                    )
            }
        }
    }
    
    // MARK: - Permission Views
    
    private var requestingPermissionView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Requesting camera access...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Camera Access Required")
                .font(.title3.weight(.semibold))
            
            Text("To scan QR codes, please allow camera access in Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    // MARK: - Camera Permission
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasPermission = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        hasPermission = true
                    } else {
                        permissionDenied = true
                    }
                }
            }
        case .denied, .restricted:
            permissionDenied = true
        @unknown default:
            permissionDenied = true
        }
    }
    
    // MARK: - Handle Scanned Code
    
    private func handleScannedCode(_ code: String) {
        guard !isProcessing else { return }
        isProcessing = true
        
        // Parse the deep link
        // Expected format: traverse://add-friend/USERNAME
        if let url = URL(string: code),
           url.scheme == "traverse",
           url.host == "add-friend",
           let username = url.pathComponents.last,
           !username.isEmpty,
           username != "/" {
            
            // Check if scanning own code
            if username.lowercased() == authViewModel.currentUser?.username.lowercased() {
                errorMessage = "You can't add yourself as a friend!"
                showError = true
                isProcessing = false
                return
            }
            
            // Success - show user profile
            HapticManager.shared.success()
            scannedUsername = username
            showUserProfile = true
            isProcessing = false
            
        } else {
            // Invalid QR code
            HapticManager.shared.error()
            errorMessage = "This doesn't appear to be a Traverse friend QR code."
            showError = true
            isProcessing = false
        }
    }
}

// MARK: - Corner Shape

struct CornerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        return path
    }
}

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewRepresentable {
    let onCodeScanned: (String) -> Void
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.onCodeScanned = onCodeScanned
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
}

class CameraPreviewUIView: UIView, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeScanned: ((String) -> Void)?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCamera()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCamera()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
    
    private func setupCamera() {
        let session = AVCaptureSession()
        
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
        
        captureSession = session
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasScanned,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = object.stringValue else {
            return
        }
        
        hasScanned = true
        onCodeScanned?(code)
        
        // Reset after delay to allow scanning again
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.hasScanned = false
        }
    }
    
    deinit {
        captureSession?.stopRunning()
    }
}

#Preview {
    QRScannerView()
        .environmentObject(AuthViewModel())
        .preferredColorScheme(.dark)
}
