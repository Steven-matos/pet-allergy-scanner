//
//  CameraView.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI
import AVFoundation
import UIKit

struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    let onError: (String) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraDevice = .rear
        picker.cameraFlashMode = .auto
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
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
                parent.onImageCaptured(image)
            } else {
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
