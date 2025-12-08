//
//  NutritionalLabelScanView.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import SwiftUI
@preconcurrency import AVFoundation

/**
 * Dedicated view for scanning nutritional labels
 *
 * Provides guided interface for capturing nutritional information
 * Uses manual capture button instead of automatic detection
 * Follows Trust & Nature design system
 */
struct NutritionalLabelScanView: View {
    let barcode: String?
    let onImageCaptured: (UIImage) -> Void
    let onCancel: () -> Void
    
    @State private var showingImagePicker = false
    @State private var cameraService = CameraService()
    @State private var showingTips = true
    @State private var isCameraReady = false
    @State private var isCapturing = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(cameraService: cameraService)
                .ignoresSafeArea()
                .id(cameraService.captureSession != nil)
            
            // Overlay with scanning guide
            VStack {
                // Top bar with Trust & Nature styling
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(ModernDesignSystem.Typography.title3)
                            .foregroundColor(.white)
                            .padding(ModernDesignSystem.Spacing.md)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // Toggle tips button
                    Button(action: { showingTips.toggle() }) {
                        Image(systemName: showingTips ? "lightbulb.fill" : "lightbulb")
                            .font(ModernDesignSystem.Typography.title3)
                            .foregroundColor(.white)
                            .padding(ModernDesignSystem.Spacing.md)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, ModernDesignSystem.Spacing.md)
                .padding(.top, ModernDesignSystem.Spacing.md)
                
                Spacer()
                
                // Scanning guide frame
                NutritionalLabelFrameOverlay()
                
                Spacer()
                
                // Tips card (collapsible)
                if showingTips {
                    ScanningTipsCard()
                        .padding(.horizontal, ModernDesignSystem.Spacing.md)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Capture button with Trust & Nature styling
                VStack(spacing: ModernDesignSystem.Spacing.md) {
                    Button(action: capturePhoto) {
                        HStack(spacing: ModernDesignSystem.Spacing.sm) {
                            if isCapturing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "camera.fill")
                                    .font(ModernDesignSystem.Typography.title2)
                            }
                            Text(isCapturing ? "Capturing..." : "Capture Label")
                                .font(ModernDesignSystem.Typography.title3)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ModernDesignSystem.Spacing.md)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    ModernDesignSystem.Colors.primary,
                                    ModernDesignSystem.Colors.primary.opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium))
                        .shadow(color: ModernDesignSystem.Colors.primary.opacity(0.4), radius: 12, x: 0, y: 4)
                    }
                    .disabled(!isCameraReady || isCapturing)
                    .opacity((!isCameraReady || isCapturing) ? 0.6 : 1.0)
                    
                    // Alternative: Choose from library
                    Button(action: { showingImagePicker = true }) {
                        HStack(spacing: ModernDesignSystem.Spacing.xs) {
                            Image(systemName: "photo.on.rectangle")
                            Text("Choose from Library")
                                .font(ModernDesignSystem.Typography.caption)
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, ModernDesignSystem.Spacing.sm)
                    }
                }
                .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                .padding(.bottom, ModernDesignSystem.Spacing.xl)
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerView(selectedImage: Binding(
                get: { nil },
                set: { image in
                    if let image = image {
                        onImageCaptured(image)
                    }
                }
            ))
        }
        .task {
            // Wait for camera to be ready
            print("📷 Waiting for camera to initialize...")
            var setupAttempts = 0
            while cameraService.captureSession == nil && setupAttempts < 100 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                setupAttempts += 1
            }
            
            guard let session = cameraService.captureSession else {
                print("❌ Camera session failed to initialize after \(Double(setupAttempts) * 0.1) seconds")
                errorMessage = "Camera failed to initialize. Please try again."
                showingError = true
                return
            }
            
            print("📷 Camera session created, starting...")
            
            // Start the session
            cameraService.startSession()
            
            // Wait for session to actually start running with periodic checks
            var runningAttempts = 0
            while session.isRunning != true && runningAttempts < 50 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                runningAttempts += 1
                
                // Check session state
                if session.isRunning {
                    break
                }
            }
            
            if session.isRunning {
                print("✅ Camera is ready for capture")
                isCameraReady = true
            } else {
                print("⚠️ Camera session failed to start after \(Double(runningAttempts) * 0.1) seconds")
                errorMessage = "Camera session failed to start. Please check camera permissions and try again."
                showingError = true
            }
        }
        .onChange(of: cameraService.captureSession?.isRunning) { oldValue, newValue in
            // Update camera ready state when session running state changes
            if newValue == true && !isCameraReady {
                print("✅ Camera session started (detected via onChange)")
                isCameraReady = true
            }
        }
        .onDisappear {
            cameraService.stopSession()
        }
        .alert("Capture Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    /**
     * Capture photo from camera
     * Validates camera is ready before attempting capture
     */
    private func capturePhoto() {
        // Ensure camera is ready before capturing
        guard isCameraReady,
              cameraService.captureSession != nil,
              cameraService.captureSession?.isRunning == true else {
            print("⚠️ Camera not ready for capture - session: \(cameraService.captureSession != nil), running: \(cameraService.captureSession?.isRunning ?? false)")
            return
        }
        
        // Prevent multiple simultaneous captures
        guard !isCapturing else {
            print("⚠️ Capture already in progress")
            return
        }
        
        isCapturing = true
        print("📸 Capturing photo from camera...")
        
        cameraService.capturePhoto { [self] result in
            isCapturing = false
            
            switch result {
            case .success(let image):
                print("✅ Photo captured successfully, size: \(image.size)")
                // Process the image to extract barcode information before passing to callback
                Task {
                    await processImageWithBarcodeDetection(image)
                }
            case .failure(let error):
                print("❌ Photo capture failed: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    /**
     * Process captured image to extract barcode information
     * This ensures barcode data is available for nutritional label scanning
     */
    private func processImageWithBarcodeDetection(_ image: UIImage) async {
        // Use the hybrid scan service to detect both barcode and OCR
        // The result is processed internally by the service
        _ = await HybridScanService.shared.performHybridScan(from: image)
        
        await MainActor.run {
            // Pass the processed image with barcode information
            onImageCaptured(image)
        }
    }
}

/**
 * Frame overlay guiding user to position nutritional label
 */
struct NutritionalLabelFrameOverlay: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Dimmed overlay with transparent frame area
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .mask(
                    Rectangle()
                        .overlay(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.large)
                                .frame(width: 300, height: 400)
                                .blendMode(.destinationOut)
                        )
                )
            
            // Frame outline with Trust & Nature colors
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.large)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            ModernDesignSystem.Colors.primary,
                            ModernDesignSystem.Colors.goldenYellow,
                            ModernDesignSystem.Colors.primary
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: 300, height: 400)
                .scaleEffect(isAnimating ? 1.02 : 1.0)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            // Label text at top of frame
            VStack {
                Text("Position Nutritional Label")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, ModernDesignSystem.Spacing.md)
                    .padding(.vertical, ModernDesignSystem.Spacing.sm)
                    .background(ModernDesignSystem.Colors.primary)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.2), radius: 4)
                    .offset(y: -220)
                
                Spacer()
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

/**
 * Tips card for scanning nutritional labels
 */
struct ScanningTipsCard: View {
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.md) {
            Image(systemName: "lightbulb.fill")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
            
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                Text("Tips for Best Results")
                    .font(ModernDesignSystem.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("• Use good lighting\n• Keep camera steady\n• Ensure text is clear")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(ModernDesignSystem.Colors.softCream.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium))
        .shadow(color: Color.black.opacity(0.2), radius: 8)
    }
}

/**
 * Simple camera service for preview and capture
 */
@Observable
@MainActor
class CameraService: NSObject {
    var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var completionHandler: ((Result<UIImage, Error>) -> Void)?
    
    override init() {
        super.init()
        Task {
            await setupCamera()
        }
    }
    
    /**
     * Setup camera capture session
     */
    private func setupCamera() async {
        // Check camera permission
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        // Handle permission
        var hasPermission = status == .authorized
        
        if status == .notDetermined {
            hasPermission = await AVCaptureDevice.requestAccess(for: .video)
        }
        
        guard hasPermission else { return }
        
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            return
        }
        
        session.beginConfiguration()
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        let output = AVCapturePhotoOutput()
        
        // Add output to session FIRST (required before setting maxPhotoDimensions)
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        // CRITICAL: Must commit configuration to connect output to video source
        // BEFORE setting maxPhotoDimensions
        session.commitConfiguration()
        
        // Now configure output with phone's MAXIMUM photo dimensions
        // This must be done AFTER the output is connected to a video source
        if #available(iOS 16.0, *) {
            // Get all supported dimensions from the camera's active format
            let supportedDimensions = camera.activeFormat.supportedMaxPhotoDimensions
            
            // Find the absolute maximum dimensions (by total pixels)
            if let maxDimension = supportedDimensions.max(by: { $0.width * $0.height < $1.width * $1.height }) {
                output.maxPhotoDimensions = maxDimension
                let megapixels = Double(maxDimension.width * maxDimension.height) / 1_000_000.0
                print("📸 Configured photo output with phone's MAX dimensions: \(maxDimension.width)x\(maxDimension.height) (~\(String(format: "%.1f", megapixels))MP)")
            } else {
                print("⚠️ No supported max dimensions found, using system default")
            }
        }
        
        await MainActor.run {
            self.captureSession = session
            self.photoOutput = output
        }
    }
    
    /**
     * Start camera session
     * Ensures session starts properly and notifies when ready
     */
    func startSession() {
        guard let session = captureSession else {
            print("⚠️ CameraService: Cannot start - session is nil")
            return
        }
        
        guard !session.isRunning else {
            print("📷 CameraService: Session already running")
            return
        }
        
        print("📷 CameraService: Starting capture session...")
        // Start session on background queue (required by AVFoundation)
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            print("📷 CameraService: Session startRunning() called")
            
            // Check if session actually started after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if session.isRunning {
                    print("✅ CameraService: Session is now running")
                } else {
                    print("⚠️ CameraService: Session failed to start")
                }
            }
        }
    }
    
    /**
     * Stop camera session
     */
    func stopSession() {
        guard let session = captureSession, session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            session.stopRunning()
        }
    }
    
    /**
     * Capture photo
     * Validates photo output is available before capturing
     */
    func capturePhoto(completion: @escaping (Result<UIImage, Error>) -> Void) {
        // Validate photo output is available
        guard let output = photoOutput else {
            print("❌ CameraService: Photo output not available")
            completion(.failure(NSError(domain: "CameraService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Camera not ready. Please wait for camera to initialize."])))
            return
        }
        
        // Validate capture session is running
        guard let session = captureSession, session.isRunning else {
            print("❌ CameraService: Capture session not running")
            completion(.failure(NSError(domain: "CameraService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Camera session not running. Please try again."])))
            return
        }
        
        print("📸 CameraService: Starting photo capture...")
        completionHandler = completion
        
        // Create photo settings matching the output's configuration
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        
        // Use the SAME max dimensions that were configured on the output
        // This MUST match the photoOutput.maxPhotoDimensions set during setup
        if #available(iOS 16.0, *) {
            let outputMaxDimensions = output.maxPhotoDimensions
            // Check if dimensions are valid (non-zero means they were configured)
            if outputMaxDimensions.width > 0 && outputMaxDimensions.height > 0 {
                // Match the output's dimensions exactly
                settings.maxPhotoDimensions = outputMaxDimensions
                print("📸 Using photo dimensions matching output: \(outputMaxDimensions.width)x\(outputMaxDimensions.height)")
            } else {
                // Output has no max dimensions set, so don't set on settings either
                print("📸 Using default dimensions (no output max dimensions configured)")
            }
        } else {
            // iOS 15 and earlier: enable high resolution
            settings.isHighResolutionPhotoEnabled = true
            print("📸 High resolution photo enabled (iOS 15 or earlier)")
        }
        
        // Capture photo with delegate
        output.capturePhoto(with: settings, delegate: self)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    /**
     * Handle photo capture completion
     * This delegate method is called when photo capture finishes
     */
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("📸 CameraService: Photo capture delegate called")
        
        if let error = error {
            print("❌ CameraService: Photo capture error: \(error.localizedDescription)")
            Task { @MainActor in
                self.completionHandler?(.failure(error))
                self.completionHandler = nil
            }
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("❌ CameraService: Failed to get image data from photo")
            Task { @MainActor in
                self.completionHandler?(.failure(NSError(domain: "CameraService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get image data from captured photo"])))
                self.completionHandler = nil
            }
            return
        }
        
        guard let image = UIImage(data: imageData) else {
            print("❌ CameraService: Failed to create UIImage from image data")
            Task { @MainActor in
                self.completionHandler?(.failure(NSError(domain: "CameraService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to process image data"])))
                self.completionHandler = nil
            }
            return
        }
        
        print("✅ CameraService: Photo processed successfully, size: \(image.size)")
        Task { @MainActor in
            self.completionHandler?(.success(image))
            self.completionHandler = nil
        }
    }
}

/**
 * Camera preview view
 * Properly connects camera session to preview layer
 */
struct CameraPreviewView: UIViewRepresentable {
    var cameraService: CameraService
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        
        // Set session if available
        if let session = cameraService.captureSession,
           let previewLayer = view.videoPreviewLayer {
            previewLayer.session = session
            previewLayer.videoGravity = .resizeAspectFill
        }
        
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        // Update session if it changed or is nil
        guard let previewLayer = uiView.videoPreviewLayer else { return }
        
        if let session = cameraService.captureSession {
            if previewLayer.session !== session {
                previewLayer.session = session
                print("📷 Camera preview: Session updated")
            }
            
            // Ensure preview layer is properly configured
            if previewLayer.videoGravity != .resizeAspectFill {
                previewLayer.videoGravity = .resizeAspectFill
            }
        } else {
            // Clear session if it becomes nil
            if previewLayer.session != nil {
                previewLayer.session = nil
                print("📷 Camera preview: Session cleared")
            }
        }
    }
    
    /**
     * Custom UIView with preview layer
     */
    class PreviewView: UIView {
        override class var layerClass: AnyClass {
            return AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer? {
            return layer as? AVCaptureVideoPreviewLayer
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            videoPreviewLayer?.videoGravity = .resizeAspectFill
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            videoPreviewLayer?.frame = bounds
        }
    }
}

#Preview {
    NutritionalLabelScanView(
        barcode: "1234567890123",
        onImageCaptured: { _ in },
        onCancel: {}
    )
}


