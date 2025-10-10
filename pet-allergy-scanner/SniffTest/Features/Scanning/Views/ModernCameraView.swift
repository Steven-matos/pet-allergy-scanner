//
//  ModernCameraView.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import SwiftUI
import AVFoundation
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

// MARK: - Modern Camera View Controller

/**
 * Modern camera view controller with real-time barcode detection
 */
@MainActor
protocol ModernCameraViewControllerDelegate: AnyObject {
    func cameraViewController(_ controller: ModernCameraViewController, didCaptureImage image: UIImage)
    func cameraViewController(_ controller: ModernCameraViewController, didDetectBarcode barcode: BarcodeResult)
    func cameraViewController(_ controller: ModernCameraViewController, didFailWithError error: Error)
    func cameraViewControllerDidCancel(_ controller: ModernCameraViewController)
}

class ModernCameraViewController: UIViewController {
    weak var delegate: ModernCameraViewControllerDelegate?
    
    // MARK: - AVFoundation Properties
    private var captureSession: AVCaptureSession!
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    private var capturePhotoOutput: AVCapturePhotoOutput!
    private var videoDataOutput: AVCaptureVideoDataOutput!
    private var videoDataOutputQueue: DispatchQueue!
    
    // MARK: - Vision Properties
    private var barcodeRequest: VNDetectBarcodesRequest!
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
    private var lastBarcodeDetectionTime: Date?
    private let barcodeDetectionCooldown: TimeInterval = 1.0 // Prevent spam detection
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupVision()
        authorizeAndSetupSession()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startCameraSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCameraSession()
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

    private func authorizeAndSetupSession() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            setupCameraSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self = self else { return }
                DispatchQueue.main.async {
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
    
    private func setupVideoDataOutput() {
        // Initialize processing queue BEFORE assigning delegate to avoid nil queue crash
        videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue", qos: .userInitiated)
        
        videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }
    }
    
    private func setupVision() {
        barcodeRequest = VNDetectBarcodesRequest { [weak self] request, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.delegate?.cameraViewController(self, didFailWithError: error)
                }
                return
            }
            
            self.processBarcodeDetectionResults(request.results)
        }
        
        // Configure for pet food barcode types
        barcodeRequest.symbologies = [.ean13, .ean8, .upce, .code128, .pdf417]
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
    
    private func updateConfiguration() {
        scanOverlayView?.isHidden = !showScanOverlay
        
        if enableRealTimeDetection && videoDataOutput == nil {
            setupVideoDataOutput()
        } else if !enableRealTimeDetection && videoDataOutput != nil {
            captureSession.removeOutput(videoDataOutput)
            videoDataOutput = nil
        }
    }
    
    private func startCameraSession() {
        guard !isSessionRunning else { return }
        guard isSessionConfigured, captureSession != nil else { return }
        
        Task { @MainActor in
            captureSession.startRunning()
            isSessionRunning = true
        }
    }
    
    private func stopCameraSession() {
        guard isSessionRunning else { return }
        
        Task { @MainActor in
            captureSession.stopRunning()
            isSessionRunning = false
        }
    }
    
    private func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        capturePhotoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    private func processBarcodeDetectionResults(_ results: [VNObservation]?) {
        guard let barcodeObservations = results as? [VNBarcodeObservation] else { return }
        
        // Check cooldown to prevent spam detection
        let now = Date()
        if let lastDetection = lastBarcodeDetectionTime,
           now.timeIntervalSince(lastDetection) < barcodeDetectionCooldown {
            return
        }
        
        // Find the highest confidence barcode
        guard let bestBarcode = barcodeObservations.max(by: { $0.confidence < $1.confidence }),
              bestBarcode.confidence > 0.7 else { return }
        
        lastBarcodeDetectionTime = now
        
        guard let payload = bestBarcode.payloadStringValue else { return }
        
        let barcodeResult = BarcodeResult(
            value: payload,
            type: bestBarcode.symbology.rawValue,
            confidence: bestBarcode.confidence,
            timestamp: now
        )
        
        DispatchQueue.main.async {
            self.delegate?.cameraViewController(self, didDetectBarcode: barcodeResult)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension ModernCameraViewController: @preconcurrency AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard enableRealTimeDetection else { return }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try imageRequestHandler.perform([barcodeRequest])
        } catch {
            // Silently handle vision errors to avoid spam
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension ModernCameraViewController: @preconcurrency AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            delegate?.cameraViewController(self, didFailWithError: error)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            delegate?.cameraViewController(self, didFailWithError: CameraError.imageProcessingFailed)
            return
        }
        
        delegate?.cameraViewController(self, didCaptureImage: image)
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
    
    var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "Camera device not found"
        case .imageProcessingFailed:
            return "Failed to process captured image"
        case .sessionConfigurationFailed:
            return "Failed to configure camera session"
        }
    }
}

// MARK: - Preview

#Preview {
    ModernCameraView(
        onImageCaptured: { _ in }
    )
}
