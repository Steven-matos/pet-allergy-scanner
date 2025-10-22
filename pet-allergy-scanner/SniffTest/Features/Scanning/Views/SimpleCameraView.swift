//
//  SimpleCameraView.swift
//  SniffTest
//
//  Created by Steven Matos on 1/10/25.
//

import SwiftUI
@preconcurrency import AVFoundation
import UIKit
import Vision

/**
 * Simple, reliable camera view for iOS 17.2+ compatibility
 * 
 * Features:
 * - Basic camera functionality
 * - Barcode detection
 * - Photo capture
 * - iOS 17.2+ compatibility
 */
struct SimpleCameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    let onBarcodeDetected: ((BarcodeResult) -> Void)?
    let onCameraControllerReady: ((SimpleCameraViewController) -> Void)?
    
    func makeUIViewController(context: Context) -> SimpleCameraViewController {
        let controller = SimpleCameraViewController()
        controller.delegate = context.coordinator
        context.coordinator.parent = self
        context.coordinator.cameraController = controller
        onCameraControllerReady?(controller)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: SimpleCameraViewController, context: Context) {
        // Update if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, SimpleCameraViewControllerDelegate {
        var parent: SimpleCameraView
        var cameraController: SimpleCameraViewController?
        
        init(_ parent: SimpleCameraView) {
            self.parent = parent
        }
        
        func cameraViewController(_ controller: SimpleCameraViewController, didCaptureImage image: UIImage) {
            parent.onImageCaptured(image)
        }
        
        func cameraViewController(_ controller: SimpleCameraViewController, didDetectBarcode barcode: BarcodeResult) {
            parent.onBarcodeDetected?(barcode)
        }
        
        func cameraViewController(_ controller: SimpleCameraViewController, didFailWithError error: Error) {
            print("Camera error: \(error.localizedDescription)")
        }
    }
}

/**
 * Simple camera view controller
 */
@MainActor
class SimpleCameraViewController: UIViewController {
    weak var delegate: SimpleCameraViewControllerDelegate?
    
    private var captureSession: AVCaptureSession?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var capturePhotoOutput: AVCapturePhotoOutput?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var videoDataOutputQueue: DispatchQueue?
    
    private var isSessionRunning = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }
    
    private func setupCamera() {
        let captureSession = AVCaptureSession()
        self.captureSession = captureSession
        
        captureSession.sessionPreset = .high
        
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
        let photoOutput = AVCapturePhotoOutput()
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            self.capturePhotoOutput = photoOutput
        }
        
        // Setup video data output for barcode detection
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        let videoQueue = DispatchQueue(label: "VideoDataOutputQueue")
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            self.videoDataOutput = videoOutput
            self.videoDataOutputQueue = videoQueue
        }
        
        // Setup preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        self.videoPreviewLayer = previewLayer
    }
    
    private func startSession() {
        guard let session = captureSession, !isSessionRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak session] in
            session?.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = true
            }
        }
    }
    
    private func stopSession() {
        guard let session = captureSession, isSessionRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak session] in
            session?.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }
    
    func capturePhoto() {
        guard let photoOutput = capturePhotoOutput, isSessionRunning else { return }
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func resumeCameraSession() {
        startSession()
    }
    
    func stopCameraForSheetPresentation() {
        stopSession()
    }
    
    func pauseCameraSession() {
        stopSession()
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension SimpleCameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request = VNDetectBarcodesRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNBarcodeObservation],
                  let bestObservation = observations.first,
                  let payload = bestObservation.payloadStringValue else { return }
            
            let barcodeResult = BarcodeResult(
                value: payload,
                type: bestObservation.symbology.rawValue,
                confidence: bestObservation.confidence,
                timestamp: Date()
            )
            
            Task { @MainActor in
                self.delegate?.cameraViewController(self, didDetectBarcode: barcodeResult)
            }
        }
        
        request.symbologies = [.ean13, .ean8, .upce, .code128, .pdf417]
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension SimpleCameraViewController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            Task { @MainActor in
                self.delegate?.cameraViewController(self, didFailWithError: error)
            }
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            Task { @MainActor in
                self.delegate?.cameraViewController(self, didFailWithError: CameraError.imageProcessingFailed)
            }
            return
        }
        
        Task { @MainActor in
            self.delegate?.cameraViewController(self, didCaptureImage: image)
        }
    }
}

// MARK: - Delegate Protocol

@MainActor
protocol SimpleCameraViewControllerDelegate: AnyObject {
    func cameraViewController(_ controller: SimpleCameraViewController, didCaptureImage image: UIImage)
    func cameraViewController(_ controller: SimpleCameraViewController, didDetectBarcode barcode: BarcodeResult)
    func cameraViewController(_ controller: SimpleCameraViewController, didFailWithError error: Error)
}

// MARK: - Camera Error
// Using CameraError from ModernCameraView.swift
