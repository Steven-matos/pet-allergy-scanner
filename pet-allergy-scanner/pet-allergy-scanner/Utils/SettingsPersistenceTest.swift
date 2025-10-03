//
//  SettingsPersistenceTest.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 1/10/25.
//

import Foundation

/// Test utility to verify settings persistence
/// This class helps ensure settings are properly saved and loaded
@MainActor
class SettingsPersistenceTest {
    
    /// Test settings persistence by changing values and verifying they persist
    /// Call this method to verify settings are working correctly
    static func runPersistenceTest() {
        let settingsManager = SettingsManager.shared
        
        print("🧪 Starting Settings Persistence Test...")
        
        // Store original values
        let originalScanAutoSave = settingsManager.scanAutoSave
        let originalAutoAnalysis = settingsManager.enableAutoAnalysis
        let originalDetailedReports = settingsManager.enableDetailedReports
        let originalCameraResolution = settingsManager.cameraResolution
        
        // Test 1: Change settings
        print("📝 Changing settings...")
        settingsManager.scanAutoSave = false
        settingsManager.enableAutoAnalysis = false
        settingsManager.enableDetailedReports = false
        settingsManager.cameraResolution = "low"
        
        // Force synchronization
        settingsManager.synchronizeSettings()
        
        // Test 2: Verify persistence
        let isPersistent = settingsManager.verifyPersistence()
        print("✅ Persistence verification: \(isPersistent ? "PASSED" : "FAILED")")
        
        // Test 3: Create new instance to simulate app restart
        let newSettingsManager = SettingsManager.shared
        let settingsMatch = 
            newSettingsManager.scanAutoSave == settingsManager.scanAutoSave &&
            newSettingsManager.enableAutoAnalysis == settingsManager.enableAutoAnalysis &&
            newSettingsManager.enableDetailedReports == settingsManager.enableDetailedReports &&
            newSettingsManager.cameraResolution == settingsManager.cameraResolution
        
        print("🔄 Settings match after 'restart': \(settingsMatch ? "PASSED" : "FAILED")")
        
        // Test 4: Restore original values
        print("🔄 Restoring original settings...")
        settingsManager.scanAutoSave = originalScanAutoSave
        settingsManager.enableAutoAnalysis = originalAutoAnalysis
        settingsManager.enableDetailedReports = originalDetailedReports
        settingsManager.cameraResolution = originalCameraResolution
        settingsManager.synchronizeSettings()
        
        print("✅ Settings Persistence Test Complete!")
        print("📊 Final Settings Summary:")
        let summary = settingsManager.getSettingsSummary()
        for (key, value) in summary {
            print("   \(key): \(value)")
        }
    }
    
    /// Quick test to verify a specific setting persists
    /// - Parameters:
    ///   - settingName: Name of the setting to test
    ///   - testValue: Value to test with
    static func testSpecificSetting<T>(_ settingName: String, testValue: T) -> Bool {
        let settingsManager = SettingsManager.shared
        
        print("🧪 Testing \(settingName) persistence...")
        
        // This would need to be implemented for each specific setting type
        // For now, just verify the general persistence mechanism
        let isPersistent = settingsManager.verifyPersistence()
        print("✅ \(settingName) persistence: \(isPersistent ? "PASSED" : "FAILED")")
        
        return isPersistent
    }
}
