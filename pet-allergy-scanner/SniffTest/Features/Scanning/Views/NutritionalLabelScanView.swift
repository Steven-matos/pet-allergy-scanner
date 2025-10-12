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
                            Image(systemName: "camera.fill")
                                .font(ModernDesignSystem.Typography.title2)
                            Text("Capture Label")
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
            while cameraService.captureSession == nil {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            cameraService.startSession()
        }
        .onDisappear {
            cameraService.stopSession()
        }
    }
    
    /**
     * Capture photo from camera
     */
    private func capturePhoto() {
        cameraService.capturePhoto { result in
            switch result {
            case .success(let image):
                onImageCaptured(image)
            case .failure(let error):
                print("Camera capture error: \(error.localizedDescription)")
            }
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
            
            // Corner guides
            VStack {
                HStack {
                    FrameCornerGuide()
                    Spacer()
                    FrameCornerGuide()
                        .rotationEffect(.degrees(90))
                }
                Spacer()
                HStack {
                    FrameCornerGuide()
                        .rotationEffect(.degrees(-90))
                    Spacer()
                    FrameCornerGuide()
                        .rotationEffect(.degrees(180))
                }
            }
            .frame(width: 300, height: 400)
            
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
 * Corner guide indicator for frame
 */
struct FrameCornerGuide: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 25, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 25))
        }
        .stroke(ModernDesignSystem.Colors.primary, lineWidth: 4)
        .frame(width: 25, height: 25)
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
        guard status == .authorized else {
            if status == .notDetermined {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                if !granted { return }
            } else {
                return
            }
        }
        
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
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        session.commitConfiguration()
        
        await MainActor.run {
            self.captureSession = session
            self.photoOutput = output
        }
    }
    
    /**
     * Start camera session
     */
    func startSession() {
        guard let session = captureSession, !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
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
     */
    func capturePhoto(completion: @escaping (Result<UIImage, Error>) -> Void) {
        completionHandler = completion
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        
        photoOutput?.capturePhoto(with: settings, delegate: self)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            Task { @MainActor in
                completionHandler?(.failure(error))
            }
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            Task { @MainActor in
                completionHandler?(.failure(NSError(domain: "CameraService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to process image"])))
            }
            return
        }
        
        Task { @MainActor in
            completionHandler?(.success(image))
        }
    }
}

/**
 * Camera preview view
 */
struct CameraPreviewView: UIViewRepresentable {
    var cameraService: CameraService
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        
        // Set session if available
        if let session = cameraService.captureSession {
            view.videoPreviewLayer.session = session
        }
        
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        // Update session if it changed
        if let session = cameraService.captureSession {
            if uiView.videoPreviewLayer.session !== session {
                uiView.videoPreviewLayer.session = session
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
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            videoPreviewLayer.videoGravity = .resizeAspectFill
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            videoPreviewLayer.frame = bounds
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


