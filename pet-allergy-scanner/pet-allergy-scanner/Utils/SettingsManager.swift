//
//  SettingsManager.swift
//  SniffTest
//
//  Created by Steven Matos on 1/10/25.
//

import Foundation
import SwiftUI

/// Centralized settings management for the pet allergy scanner app
/// Provides type-safe access to user preferences with proper defaults
/// Follows SOLID principles with single responsibility for settings management
@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // MARK: - Published Properties for UI Binding
    
    /// Controls whether scans are automatically saved to history
    @Published var scanAutoSave: Bool {
        didSet {
            UserDefaults.standard.set(scanAutoSave, forKey: "scanAutoSave")
            UserDefaults.standard.synchronize() // Force immediate write to disk
        }
    }
    
    /// Controls whether ingredient analysis starts automatically after text extraction
    @Published var enableAutoAnalysis: Bool {
        didSet {
            UserDefaults.standard.set(enableAutoAnalysis, forKey: "enableAutoAnalysis")
        }
    }
    
    /// Controls the level of detail shown in safety reports
    @Published var enableDetailedReports: Bool {
        didSet {
            UserDefaults.standard.set(enableDetailedReports, forKey: "enableDetailedReports")
        }
    }
    
    /// Controls camera resolution for scanning
    @Published var cameraResolution: String {
        didSet {
            UserDefaults.standard.set(cameraResolution, forKey: "cameraResolution")
        }
    }
    
    /// Controls push notifications (delegated to NotificationSettingsManager)
    /// This property is kept for backward compatibility but delegates to NotificationSettingsManager
    var enableNotifications: Bool {
        get {
            return NotificationSettingsManager.shared.enableNotifications
        }
        set {
            NotificationSettingsManager.shared.enableNotifications = newValue
        }
    }
    
    /// Controls haptic feedback
    @Published var enableHapticFeedback: Bool {
        didSet {
            UserDefaults.standard.set(enableHapticFeedback, forKey: "enableHapticFeedback")
        }
    }
    
    /// Controls analytics collection
    @Published var enableAnalytics: Bool {
        didSet {
            UserDefaults.standard.set(enableAnalytics, forKey: "enableAnalytics")
        }
    }
    
    /// User's preferred language
    @Published var preferredLanguage: String {
        didSet {
            UserDefaults.standard.set(preferredLanguage, forKey: "preferredLanguage")
        }
    }
    
    /// Default pet ID for scans
    @Published var defaultPetId: String? {
        didSet {
            UserDefaults.standard.set(defaultPetId, forKey: "defaultPetId")
        }
    }
    
    // MARK: - Private Initializer
    
    private init() {
        // Load settings from UserDefaults with sensible defaults
        self.scanAutoSave = UserDefaults.standard.object(forKey: "scanAutoSave") as? Bool ?? true
        self.enableAutoAnalysis = UserDefaults.standard.object(forKey: "enableAutoAnalysis") as? Bool ?? true
        self.enableDetailedReports = UserDefaults.standard.object(forKey: "enableDetailedReports") as? Bool ?? true
        self.cameraResolution = UserDefaults.standard.string(forKey: "cameraResolution") ?? "high"
        // enableNotifications is now handled by NotificationSettingsManager
        self.enableHapticFeedback = UserDefaults.standard.object(forKey: "enableHapticFeedback") as? Bool ?? true
        self.enableAnalytics = UserDefaults.standard.object(forKey: "enableAnalytics") as? Bool ?? true
        self.preferredLanguage = UserDefaults.standard.string(forKey: "preferredLanguage") ?? "en"
        self.defaultPetId = UserDefaults.standard.string(forKey: "defaultPetId")
    }
    
    // MARK: - Public Methods
    
    /// Reset all settings to their default values
    /// Used when user wants to restore factory settings
    func resetToDefaults() {
        scanAutoSave = true
        enableAutoAnalysis = true
        enableDetailedReports = true
        cameraResolution = "high"
        // enableNotifications is now handled by NotificationSettingsManager
        enableHapticFeedback = true
        enableAnalytics = true
        preferredLanguage = "en"
        defaultPetId = nil
        
        // Reset notification settings through NotificationSettingsManager
        NotificationSettingsManager.shared.resetToDefaults()
        
        // Force synchronization to ensure all changes are persisted
        UserDefaults.standard.synchronize()
        
        // Trigger haptic feedback for user confirmation
        HapticFeedback.success()
    }
    
    /// Force synchronization of all settings to disk
    /// Call this method to ensure all settings are immediately persisted
    func synchronizeSettings() {
        UserDefaults.standard.synchronize()
    }
    
    /// Verify that settings are properly persisted
    /// Returns true if all settings match their stored values
    func verifyPersistence() -> Bool {
        let storedScanAutoSave = UserDefaults.standard.object(forKey: "scanAutoSave") as? Bool ?? true
        let storedAutoAnalysis = UserDefaults.standard.object(forKey: "enableAutoAnalysis") as? Bool ?? true
        let storedDetailedReports = UserDefaults.standard.object(forKey: "enableDetailedReports") as? Bool ?? true
        let storedCameraResolution = UserDefaults.standard.string(forKey: "cameraResolution") ?? "high"
        
        return scanAutoSave == storedScanAutoSave &&
               enableAutoAnalysis == storedAutoAnalysis &&
               enableDetailedReports == storedDetailedReports &&
               cameraResolution == storedCameraResolution
    }
    
    /// Get a summary of all current settings for debugging
    func getSettingsSummary() -> [String: Any] {
        return [
            "scanAutoSave": scanAutoSave,
            "enableAutoAnalysis": enableAutoAnalysis,
            "enableDetailedReports": enableDetailedReports,
            "cameraResolution": cameraResolution,
            "enableNotifications": enableNotifications,
            "enableHapticFeedback": enableHapticFeedback,
            "enableAnalytics": enableAnalytics,
            "preferredLanguage": preferredLanguage,
            "defaultPetId": defaultPetId ?? "nil",
            "notificationSettings": NotificationSettingsManager.shared.getSettingsSummary()
        ]
    }
    
    /// Get notification settings summary for debugging
    func getNotificationSettingsSummary() -> [String: Any] {
        return NotificationSettingsManager.shared.getSettingsSummary()
    }
    
    /// Get camera resolution as AVFoundation preset
    /// Converts string setting to appropriate camera preset
    var cameraResolutionPreset: AVCaptureSession.Preset {
        switch cameraResolution {
        case "low":
            return .low
        case "medium":
            return .medium
        case "high":
            return .high
        default:
            return .high
        }
    }
    
    /// Check if detailed analysis should be shown
    /// Used to determine report detail level
    var shouldShowDetailedAnalysis: Bool {
        return enableDetailedReports
    }
    
    /// Check if scan should be auto-saved
    /// Used by scan services to determine save behavior
    var shouldAutoSaveScans: Bool {
        return scanAutoSave
    }
    
    /// Check if analysis should start automatically
    /// Used by scan views to determine auto-analysis behavior
    var shouldAutoAnalyze: Bool {
        return enableAutoAnalysis
    }
}

// MARK: - Camera Resolution Extension

import AVFoundation

extension SettingsManager {
    /// Get camera resolution description for UI display
    var cameraResolutionDescription: String {
        switch cameraResolution {
        case "low":
            return "Low (Faster)"
        case "medium":
            return "Medium (Balanced)"
        case "high":
            return "High (Best)"
        default:
            return "High (Best)"
        }
    }
}
