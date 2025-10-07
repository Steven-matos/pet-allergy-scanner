//
//  CameraView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI
import AVFoundation
import UIKit

struct CameraView: UIViewControllerRepresentable {
    let cameraResolution: AVCaptureSession.Preset
    let onImageCaptured: (UIImage) -> Void
    let onError: (String) -> Void
    
    init(cameraResolution: AVCaptureSession.Preset = .high, onImageCaptured: @escaping (UIImage) -> Void, onError: @escaping (String) -> Void) {
        self.cameraResolution = cameraResolution
        self.onImageCaptured = onImageCaptured
        self.onError = onError
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        // Check if running on simulator
        #if targetEnvironment(simulator)
        return createSimulatorViewController(context: context)
        #else
        return createCameraViewController(context: context)
        #endif
    }
    
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
    
    private func createCameraViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraDevice = .rear
        picker.cameraFlashMode = .auto
        picker.allowsEditing = false
        
        // Set camera quality and resolution
        picker.videoQuality = .typeHigh
        
        // Accessibility
        picker.accessibilityLabel = "Camera for scanning ingredient labels"
        picker.accessibilityHint = "Point the camera at the ingredient list on pet food packaging"
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                // Validate image dimensions
                guard image.size.width > 0 && image.size.height > 0 else {
                    HapticFeedback.error()
                    parent.onError("Invalid image dimensions")
                    picker.dismiss(animated: true)
                    return
                }
                
                // Provide haptic feedback for successful capture
                HapticFeedback.success()
                parent.onImageCaptured(image)
            } else {
                // Provide haptic feedback for error
                HapticFeedback.error()
                parent.onError("Failed to capture image")
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}


#Preview {
    CameraView(
        onImageCaptured: { image in
            print("Image captured: \(image)")
        },
        onError: { error in
            print("Camera error: \(error)")
        }
    )
}
