//
//  ModernCameraView.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import SwiftUI
@preconcurrency import AVFoundation
import UIKit
import Vision

/**
 * Modern camera view with real-time barcode detection and enhanced UX
 * 
 * Features:
 * - Real-time barcode detection with overlay
 * - Smart frame detection for ingredient lists
 * - Haptic feedback for successful captures
 * - Progressive disclosure of scan steps
 * - Modern iOS design patterns
 * 
 * Uses latest SwiftUI and AVFoundation patterns for optimal performance
 */
struct ModernCameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    let onBarcodeDetected: ((BarcodeResult) -> Void)?
    
    // Configuration
    let enableRealTimeDetection: Bool
    let showScanOverlay: Bool
    let hapticFeedback: Bool
    
    init(
        onImageCaptured: @escaping (UIImage) -> Void,
        onBarcodeDetected: ((BarcodeResult) -> Void)? = nil,
        enableRealTimeDetection: Bool = true,
        showScanOverlay: Bool = true,
        hapticFeedback: Bool = true
    ) {
        self.onImageCaptured = onImageCaptured
        self.onBarcodeDetected = onBarcodeDetected
        self.enableRealTimeDetection = enableRealTimeDetection
        self.showScanOverlay = showScanOverlay
        self.hapticFeedback = hapticFeedback
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        return isCameraUsable() ? createModernCameraViewController(context: context)
                                : createSimulatorViewController(context: context)
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Update configuration if needed
        if let cameraVC = uiViewController as? ModernCameraViewController {
            cameraVC.updateConfiguration(
                enableRealTimeDetection: enableRealTimeDetection,
                showScanOverlay: showScanOverlay,
                hapticFeedback: hapticFeedback
            )
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Private Methods
    
    private func createSimulatorViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        
        // Accessibility
        picker.accessibilityLabel = "Photo library for testing ingredient scanning"
        picker.accessibilityHint = "Select an image from your photo library to test ingredient scanning"
        
        return picker
    }
    
    private func createModernCameraViewController(context: Context) -> ModernCameraViewController {
        let cameraVC = ModernCameraViewController()
        cameraVC.delegate = context.coordinator
        cameraVC.configure(
            enableRealTimeDetection: enableRealTimeDetection,
            showScanOverlay: showScanOverlay,
            hapticFeedback: hapticFeedback
        )
        return cameraVC
    }
    
    // MARK: - Coordinator
    
    @MainActor
    class Coordinator: NSObject, ModernCameraViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ModernCameraView
        
        init(_ parent: ModernCameraView) {
            self.parent = parent
        }
        
        // MARK: - ModernCameraViewControllerDelegate
        
        func cameraViewController(_ controller: ModernCameraViewController, didCaptureImage image: UIImage) {
            validateAndProcessImage(image)
        }
        
        func cameraViewController(_ controller: ModernCameraViewController, didDetectBarcode barcode: BarcodeResult) {
            if parent.hapticFeedback {
                HapticFeedback.success()
            }
            parent.onBarcodeDetected?(barcode)
        }
        
        func cameraViewController(_ controller: ModernCameraViewController, didFailWithError error: Error) {
            // Handle error silently or show in UI
        }
        
        func cameraViewControllerDidCancel(_ controller: ModernCameraViewController) {
            // Handle cancel if needed
        }
        
        // MARK: - UIImagePickerControllerDelegate (Simulator)
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                validateAndProcessImage(image)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            // Handle cancel if needed
        }
        
        // MARK: - Private Methods
        
        private func validateAndProcessImage(_ image: UIImage) {
            // Validate image dimensions
            guard image.size.width > 0 && image.size.height > 0 else {
                if parent.hapticFeedback {
                    HapticFeedback.error()
                }
                return
            }
            
            // Provide haptic feedback for successful capture
            if parent.hapticFeedback {
                HapticFeedback.success()
            }
            
            parent.onImageCaptured(image)
        }
    }
}

// MARK: - Camera Capability Helpers

extension ModernCameraView {
    /// Returns true when the device can present a live camera feed (hardware + permission state)
    private func isCameraUsable() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        if !UIImagePickerController.isSourceTypeAvailable(.camera) { return false }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .restricted || status == .denied { return false }
        return true
        #endif
    }
}

// MARK: - Camera Delegate Protocol

@MainActor
protocol ModernCameraViewControllerDelegate: AnyObject {
    func cameraViewController(_ controller: ModernCameraViewController, didCaptureImage image: UIImage)
    func cameraViewController(_ controller: ModernCameraViewController, didDetectBarcode barcode: BarcodeResult)
    func cameraViewController(_ controller: ModernCameraViewController, didFailWithError error: Error)
    func cameraViewControllerDidCancel(_ controller: ModernCameraViewController)
}

// MARK: - Video Capture Delegate (Non-Isolated)

/// Sendable barcode data extracted from Vision observations
/// Allows safe transfer across isolation boundaries in Swift 6
struct BarcodeData: Sendable {
    let payloadString: String
    let symbology: String
    let confidence: Float
}

/// Isolated camera delegate that handles video frames on background queue
/// This architecture follows Swift 6 best practices by keeping delegate separate from @MainActor
final class VideoCaptureDelegate: NSObject, @unchecked Sendable {
    /// Callback for barcode detection - dispatches to main actor
    /// - Note: Uses @Sendable closure with Sendable data type for Swift 6 compliance
    var onBarcodeDetected: (@Sendable ([BarcodeData]) -> Void)?
    
    /// Barcode symbologies to detect
    nonisolated private let symbologies: [VNBarcodeSymbology] = [.ean13, .ean8, .upce, .code128, .pdf417]
    
    /// Frame processing control flags - accessed exclusively from serial video data output queue
    /// - Note: nonisolated(unsafe) because access is serialized by AVFoundation's delegate queue
    nonisolated(unsafe) private var shouldProcessFrames = false
    nonisolated(unsafe) private var deferFrameProcessing = false
    nonisolated(unsafe) private var frameProcessCounter = 0
    
    /// Enables frame processing
    func startProcessing() {
        shouldProcessFrames = true
        deferFrameProcessing = false
        frameProcessCounter = 0
    }
    
    /// Disables frame processing for teardown
    func stopProcessing() {
        shouldProcessFrames = false
    }
    
    /// Resumes frame processing after throttle
    func resumeProcessing() {
        deferFrameProcessing = false
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension VideoCaptureDelegate: AVCaptureVideoDataOutputSampleBufferDelegate {
    /// Processes video frames on background queue (nonisolated by default for NSObject)
    /// - Note: No actor isolation issues because this class is not actor-isolated
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Early exit checks on background queue
        guard shouldProcessFrames else { return }
        guard !deferFrameProcessing else { return }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Capture callback before creating request
        let callback = onBarcodeDetected
        
        // Create new request with completion handler for Swift 6 compliance
        let barcodeRequest = VNDetectBarcodesRequest { request, error in
            guard error == nil else { return }
            
            // Extract observations and convert to Sendable data on background thread
            if let observations = request.results as? [VNBarcodeObservation], !observations.isEmpty {
                // Convert non-Sendable observations to Sendable data structures
                let barcodeData = observations.compactMap { observation -> BarcodeData? in
                    guard let payload = observation.payloadStringValue else { return nil }
                    return BarcodeData(
                        payloadString: payload,
                        symbology: observation.symbology.rawValue,
                        confidence: observation.confidence
                    )
                }
                
                // Invoke callback with Sendable data (safe for cross-isolation transfer)
                if !barcodeData.isEmpty {
                    callback?(barcodeData)
                }
            }
        }
        
        // Configure symbologies
        barcodeRequest.symbologies = symbologies
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try handler.perform([barcodeRequest])
            
            // Frame throttling to prevent queue overload
            frameProcessCounter += 1
            if frameProcessCounter % 15 == 0 {
                deferFrameProcessing = true
                // Resume processing after a brief delay on background queue
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.resumeProcessing()
                }
            }
        } catch {
            // Silently handle vision errors
        }
    }
}

/**
 * Modern camera view controller with real-time barcode detection
 * 
 * Architecture:
 * - Uses @MainActor for UI and session management
 * - Separate VideoCaptureDelegate handles frame processing on background queue
 * - Follows Swift 6 best practices for actor isolation
 */
@MainActor
class ModernCameraViewController: UIViewController {
    /// Main actor delegate for UI updates
    weak var delegate: ModernCameraViewControllerDelegate?
    
    // MARK: - AVFoundation Properties
    private var captureSession: AVCaptureSession!
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    private var capturePhotoOutput: AVCapturePhotoOutput!
    private var videoDataOutput: AVCaptureVideoDataOutput!
    private var videoDataOutputQueue: DispatchQueue!
    
    // MARK: - Delegate Properties
    /// Non-isolated delegate for video frame processing
    /// - Note: Separate from @MainActor to avoid actor isolation issues
    private var videoCaptureDelegate: VideoCaptureDelegate!
    private let barcodeService = BarcodeService.shared
    
    // MARK: - UI Properties
    private var scanOverlayView: ScanOverlayView!
    private var controlsView: CameraControlsView!
    
    // MARK: - Configuration
    private var enableRealTimeDetection = true
    private var showScanOverlay = true
    private var hapticFeedback = true
    
    // MARK: - State
    private var isSessionRunning = false
    private var isSessionConfigured = false
    /// Tracks last barcode detection for cooldown
    private var lastBarcodeDetectionTime: Date?
    private let barcodeDetectionCooldown: TimeInterval = 1.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupVideoCaptureDelegate()
        authorizeAndSetupSession()
        setupNotificationObservers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startCameraSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCameraSession()
    }
    
    deinit {
        // Stop processing and remove observers
        videoCaptureDelegate?.stopProcessing()
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        videoPreviewLayer?.frame = view.bounds
    }
    
    // MARK: - Public Methods
    
    func configure(enableRealTimeDetection: Bool, showScanOverlay: Bool, hapticFeedback: Bool) {
        self.enableRealTimeDetection = enableRealTimeDetection
        self.showScanOverlay = showScanOverlay
        self.hapticFeedback = hapticFeedback
        updateConfiguration()
    }
    
    func updateConfiguration(enableRealTimeDetection: Bool, showScanOverlay: Bool, hapticFeedback: Bool) {
        self.enableRealTimeDetection = enableRealTimeDetection
        self.showScanOverlay = showScanOverlay
        self.hapticFeedback = hapticFeedback
        updateConfiguration()
    }
    
    // MARK: - Private Methods
    
    private func setupCameraSession() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high
        
        // Setup camera input
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            delegate?.cameraViewController(self, didFailWithError: CameraError.deviceNotFound)
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
        } catch {
            delegate?.cameraViewController(self, didFailWithError: error)
            return
        }
        
        // Setup photo output
        capturePhotoOutput = AVCapturePhotoOutput()
        if captureSession.canAddOutput(capturePhotoOutput) {
            captureSession.addOutput(capturePhotoOutput)
        }
        
        // Setup video data output for real-time barcode detection
        if enableRealTimeDetection {
            setupVideoDataOutput()
        }
        
        // Setup preview layer
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.videoGravity = .resizeAspectFill
        videoPreviewLayer.frame = view.bounds
        view.layer.addSublayer(videoPreviewLayer)
        
        isSessionConfigured = true
    }

    /// Authorizes camera access and sets up the capture session
    /// - Note: Handles all authorization states including runtime changes
    private func authorizeAndSetupSession() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            setupCameraSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                Task { @MainActor in
                    if granted {
                        self.setupCameraSession()
                        self.startCameraSession()
                    } else {
                        self.delegate?.cameraViewController(self, didFailWithError: CameraError.deviceNotFound)
                    }
                }
            }
        case .denied, .restricted:
            delegate?.cameraViewController(self, didFailWithError: CameraError.deviceNotFound)
        @unknown default:
            delegate?.cameraViewController(self, didFailWithError: CameraError.sessionConfigurationFailed)
        }
    }
    
    /// Sets up video data output for real-time barcode detection
    /// - Note: Requires captureSession and videoCaptureDelegate to be initialized first
    private func setupVideoDataOutput() {
        // Guard against nil captureSession - can happen if called before viewDidLoad
        guard captureSession != nil, videoCaptureDelegate != nil else { return }
        
        // Initialize processing queue BEFORE assigning delegate to avoid nil queue crash
        videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue", qos: .userInitiated)
        
        videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        
        // Use isolated VideoCaptureDelegate instead of self
        videoDataOutput.setSampleBufferDelegate(videoCaptureDelegate, queue: videoDataOutputQueue)
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }
    }
    
    /// Sets up the isolated video capture delegate for frame processing
    /// - Note: Delegate handles all barcode detection on background queue
    private func setupVideoCaptureDelegate() {
        videoCaptureDelegate = VideoCaptureDelegate()
        
        // Set callback that runs on main actor for barcode results
        // BarcodeData is Sendable, so this is safe for Swift 6 strict concurrency
        videoCaptureDelegate.onBarcodeDetected = { [weak self] barcodeData in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.processBarcodeDetectionResults(barcodeData)
            }
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Setup scan overlay
        if showScanOverlay {
            scanOverlayView = ScanOverlayView()
            scanOverlayView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(scanOverlayView)
            
            NSLayoutConstraint.activate([
                scanOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
                scanOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                scanOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                scanOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
        
        // Setup controls
        controlsView = CameraControlsView()
        controlsView.delegate = self
        controlsView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlsView)
        
        NSLayoutConstraint.activate([
            controlsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlsView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            controlsView.heightAnchor.constraint(equalToConstant: 120)
        ])
    }
    
    /// Updates the camera configuration based on current settings
    /// - Note: Safe to call before session is configured. Includes defensive checks for nil session.
    private func updateConfiguration() {
        // Safely update UI overlay
        scanOverlayView?.isHidden = !showScanOverlay
        
        // Only modify capture session outputs if session is configured and valid
        guard isSessionConfigured, let session = captureSession else { return }
        
        // Update video data output for real-time detection
        if enableRealTimeDetection && videoDataOutput == nil {
            setupVideoDataOutput()
        } else if !enableRealTimeDetection, let output = videoDataOutput {
            session.removeOutput(output)
            videoDataOutput = nil
        }
    }
    
    /// Starts the camera session on a background queue
    /// - Note: AVCaptureSession start/stop should be called on background queue to avoid blocking main thread
    private func startCameraSession() {
        guard !isSessionRunning else { return }
        guard isSessionConfigured else { return }
        
        // Enable frame processing in isolated delegate
        videoCaptureDelegate?.startProcessing()
        
        // Capture session in nonisolated context for background dispatch
        let session = captureSession
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            session?.startRunning()
            Task { @MainActor [weak self] in
                self?.isSessionRunning = true
            }
        }
    }
    
    /// Stops the camera session safely on a background queue
    /// - Note: AVCaptureSession stopRunning() is a blocking call that should run on background queue
    /// This prevents deadlocks and ensures Vision callbacks complete before session stops
    private func stopCameraSession() {
        guard isSessionRunning else { return }
        
        // CRITICAL: Stop frame processing FIRST to prevent new operations
        // This prevents captureOutput from processing frames during teardown
        videoCaptureDelegate?.stopProcessing()
        isSessionRunning = false
        
        // Capture session in nonisolated context for background dispatch
        let session = captureSession
        DispatchQueue.global(qos: .userInitiated).async {
            // Wait briefly to allow in-flight frames to complete
            Thread.sleep(forTimeInterval: 0.1)
            session?.stopRunning()
        }
    }
    
    /// Captures a photo using the camera
    /// - Note: Includes defensive checks for nil outputs to prevent crashes
    private func capturePhoto() {
        guard let photoOutput = capturePhotoOutput,
              isSessionRunning else {
            delegate?.cameraViewController(self, didFailWithError: CameraError.sessionConfigurationFailed)
            return
        }
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    
    /// Sets up notification observers for runtime authorization changes
    /// - Note: Handles cases where camera access is revoked while app is running
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    /// Handles app entering foreground by checking authorization status
    /// - Note: Revalidates camera access in case permissions changed while app was backgrounded
    @objc private func handleAppWillEnterForeground() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        guard status == .authorized else {
            stopCameraSession()
            delegate?.cameraViewController(self, didFailWithError: CameraError.authorizationRevoked)
            return
        }
        
        // Restart session if it was stopped
        if isSessionConfigured && !isSessionRunning {
            startCameraSession()
        }
    }
    
    /// Processes barcode detection results on main actor
    /// - Parameter barcodeData: Sendable barcode data extracted from Vision framework
    /// - Note: Must be called from main actor context to ensure thread-safe access to properties
    private func processBarcodeDetectionResults(_ barcodeData: [BarcodeData]) {
        // Ignore results if session stopped (prevents processing during teardown)
        guard isSessionRunning else { return }
        guard !barcodeData.isEmpty else { return }
        
        // Check cooldown to prevent spam detection
        let now = Date()
        if let lastDetection = lastBarcodeDetectionTime,
           now.timeIntervalSince(lastDetection) < barcodeDetectionCooldown {
            return
        }
        
        // Find the highest confidence barcode
        guard let bestBarcode = barcodeData.max(by: { $0.confidence < $1.confidence }),
              bestBarcode.confidence > 0.7 else { return }
        
        lastBarcodeDetectionTime = now
        
        let barcodeResult = BarcodeResult(
            value: bestBarcode.payloadString,
            type: bestBarcode.symbology,
            confidence: bestBarcode.confidence,
            timestamp: now
        )
        
        delegate?.cameraViewController(self, didDetectBarcode: barcodeResult)
    }
}


// MARK: - AVCapturePhotoCaptureDelegate

extension ModernCameraViewController: AVCapturePhotoCaptureDelegate {
    /// Processes captured photo on background queue
    /// - Note: Called on AVCapturePhotoOutput's delegate queue - marked nonisolated
    /// All accesses to self are wrapped in Task { @MainActor } to ensure proper actor isolation
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.delegate?.cameraViewController(self, didFailWithError: error)
            }
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.delegate?.cameraViewController(self, didFailWithError: CameraError.imageProcessingFailed)
            }
            return
        }
        
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.delegate?.cameraViewController(self, didCaptureImage: image)
        }
    }
}

// MARK: - CameraControlsViewDelegate

@MainActor
protocol CameraControlsViewDelegate: AnyObject {
    func cameraControlsViewDidTapCapture(_ view: CameraControlsView)
    func cameraControlsViewDidTapCancel(_ view: CameraControlsView)
}

extension ModernCameraViewController: CameraControlsViewDelegate {
    func cameraControlsViewDidTapCapture(_ view: CameraControlsView) {
        capturePhoto()
    }
    
    func cameraControlsViewDidTapCancel(_ view: CameraControlsView) {
        delegate?.cameraViewControllerDidCancel(self)
    }
}

// MARK: - Camera Error Types

enum CameraError: LocalizedError {
    case deviceNotFound
    case imageProcessingFailed
    case sessionConfigurationFailed
    case authorizationRevoked
    
    var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "Camera device not found"
        case .imageProcessingFailed:
            return "Failed to process captured image"
        case .sessionConfigurationFailed:
            return "Failed to configure camera session"
        case .authorizationRevoked:
            return "Camera access was revoked. Please enable camera access in Settings."
        }
    }
}

// MARK: - Preview

#Preview {
    ModernCameraView(
        onImageCaptured: { _ in }
    )
}

