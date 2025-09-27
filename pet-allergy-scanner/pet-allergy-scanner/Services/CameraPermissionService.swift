//
//  CameraPermissionService.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import AVFoundation
import UIKit
import Observation

/// Service for managing camera permissions and access
@Observable
class CameraPermissionService {
    static let shared = CameraPermissionService()
    
    var authorizationStatus: AVAuthorizationStatus = .notDetermined
    
    private init() {
        updateAuthorizationStatus()
    }
    
    /// Update the current authorization status
    private func updateAuthorizationStatus() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    /// Request camera permission from the user
    /// - Parameter completion: Completion handler with the authorization status
    func requestCameraPermission(completion: @escaping (AVAuthorizationStatus) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.updateAuthorizationStatus()
                completion(self?.authorizationStatus ?? .denied)
            }
        }
    }
    
    /// Check if camera is available and authorized
    var isCameraAvailable: Bool {
        return UIImagePickerController.isSourceTypeAvailable(.camera) && 
               authorizationStatus == .authorized
    }
    
    /// Get user-friendly message for current permission status
    var permissionMessage: String {
        switch authorizationStatus {
        case .notDetermined:
            return "Camera access is required to scan ingredient labels. Please allow camera access in Settings."
        case .denied, .restricted:
            return "Camera access is denied. Please enable camera access in Settings to scan ingredient labels."
        case .authorized:
            return "Camera access is granted."
        @unknown default:
            return "Unknown camera permission status."
        }
    }
    
    /// Open app settings for camera permission
    func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}
