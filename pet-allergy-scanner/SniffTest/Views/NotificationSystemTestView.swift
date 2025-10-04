//
//  NotificationSystemTestView.swift
//  SniffTest
//
//  Created by Steven Matos on 1/10/25.
//

import SwiftUI

/// Test view for verifying the centralized notification system works properly
/// This view can be used to test all notification settings and ensure no freezing occurs
struct NotificationSystemTestView: View {
    @StateObject private var notificationSettingsManager = NotificationSettingsManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var testResults: [String] = []
    @State private var isRunningTests = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Notification Settings Status") {
                    HStack {
                        Text("Master Notifications")
                        Spacer()
                        Text(notificationSettingsManager.enableNotifications ? "Enabled" : "Disabled")
                            .foregroundColor(notificationSettingsManager.enableNotifications ? .green : .red)
                    }
                    
                    HStack {
                        Text("Birthday Surprises")
                        Spacer()
                        Text("Easter Egg")
                            .foregroundColor(.yellow)
                    }
                    
                    HStack {
                        Text("Engagement Notifications")
                        Spacer()
                        Text(notificationSettingsManager.engagementNotificationsEnabled ? "Enabled" : "Disabled")
                            .foregroundColor(notificationSettingsManager.engagementNotificationsEnabled ? .green : .red)
                    }
                    
                    HStack {
                        Text("Authorization Status")
                        Spacer()
                        Text(notificationSettingsManager.isAuthorized ? "Authorized" : "Not Authorized")
                            .foregroundColor(notificationSettingsManager.isAuthorized ? .green : .orange)
                    }
                }
                
                Section("Toggle Tests") {
                    Button("Test Birthday Easter Egg") {
                        testBirthdayEasterEgg()
                    }
                    .disabled(isRunningTests)
                    
                    Button("Test Engagement Toggle (No Freeze)") {
                        testEngagementToggle()
                    }
                    .disabled(isRunningTests)
                    
                    Button("Test Master Toggle (No Freeze)") {
                        testMasterToggle()
                    }
                    .disabled(isRunningTests)
                }
                
                Section("Settings Integration Tests") {
                    Button("Test SettingsManager Integration") {
                        testSettingsManagerIntegration()
                    }
                    .disabled(isRunningTests)
                    
                    Button("Test Reset to Defaults") {
                        testResetToDefaults()
                    }
                    .disabled(isRunningTests)
                }
                
                Section("Test Results") {
                    if testResults.isEmpty {
                        Text("No tests run yet")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(testResults, id: \.self) { result in
                            Text(result)
                                .font(.caption)
                        }
                    }
                }
                
                Section("Actions") {
                    Button("Clear Test Results") {
                        testResults.removeAll()
                    }
                    
                    Button("Run All Tests") {
                        runAllTests()
                    }
                    .disabled(isRunningTests)
                }
            }
            .navigationTitle("Notification System Test")
            .onAppear {
                Task {
                    await notificationSettingsManager.checkAuthorizationStatus()
                }
            }
        }
    }
    
    // MARK: - Test Methods
    
    private func testBirthdayEasterEgg() {
        isRunningTests = true
        testResults.append("🔄 Testing birthday easter egg...")
        
        let startTime = Date()
        // Test the easter egg functionality
        let hasBeenShown = notificationSettingsManager.hasBirthdayCelebrationBeenShown(for: "test_pet_id")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            if duration < 0.05 { // Should be very fast
                self.testResults.append("✅ Birthday easter egg test passed (took \(String(format: "%.3f", duration))s)")
                self.testResults.append("ℹ️ Easter egg status: \(hasBeenShown ? "Already shown" : "Not shown yet")")
            } else {
                self.testResults.append("❌ Birthday easter egg test failed - too slow (took \(String(format: "%.3f", duration))s)")
            }
            
            self.isRunningTests = false
        }
    }
    
    private func testEngagementToggle() {
        isRunningTests = true
        testResults.append("🔄 Testing engagement toggle...")
        
        let startTime = Date()
        notificationSettingsManager.toggleEngagementNotifications()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            if duration < 0.05 { // Should be very fast
                self.testResults.append("✅ Engagement toggle test passed (took \(String(format: "%.3f", duration))s)")
            } else {
                self.testResults.append("❌ Engagement toggle test failed - too slow (took \(String(format: "%.3f", duration))s)")
            }
            
            self.isRunningTests = false
        }
    }
    
    private func testMasterToggle() {
        isRunningTests = true
        testResults.append("🔄 Testing master toggle...")
        
        let startTime = Date()
        notificationSettingsManager.toggleMasterNotifications()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            if duration < 0.05 { // Should be very fast
                self.testResults.append("✅ Master toggle test passed (took \(String(format: "%.3f", duration))s)")
            } else {
                self.testResults.append("❌ Master toggle test failed - too slow (took \(String(format: "%.3f", duration))s)")
            }
            
            self.isRunningTests = false
        }
    }
    
    private func testSettingsManagerIntegration() {
        isRunningTests = true
        testResults.append("🔄 Testing SettingsManager integration...")
        
        // Test that SettingsManager.enableNotifications reflects NotificationSettingsManager
        let originalValue = settingsManager.enableNotifications
        settingsManager.enableNotifications.toggle()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let newValue = self.settingsManager.enableNotifications
            let notificationValue = self.notificationSettingsManager.enableNotifications
            
            if newValue == notificationValue {
                self.testResults.append("✅ SettingsManager integration test passed")
            } else {
                self.testResults.append("❌ SettingsManager integration test failed - values don't match")
            }
            
            // Restore original value
            self.settingsManager.enableNotifications = originalValue
            self.isRunningTests = false
        }
    }
    
    private func testResetToDefaults() {
        isRunningTests = true
        testResults.append("🔄 Testing reset to defaults...")
        
        let startTime = Date()
        notificationSettingsManager.resetToDefaults()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            // Check if all settings are at default values
            let allDefaults = self.notificationSettingsManager.enableNotifications &&
                            self.notificationSettingsManager.engagementNotificationsEnabled
            
            if allDefaults && duration < 1.0 {
                self.testResults.append("✅ Reset to defaults test passed (took \(String(format: "%.3f", duration))s)")
            } else {
                self.testResults.append("❌ Reset to defaults test failed - not all defaults or too slow")
            }
            
            self.isRunningTests = false
        }
    }
    
    private func runAllTests() {
        testResults.removeAll()
        testResults.append("🚀 Starting comprehensive notification system tests...")
        
        // Run tests sequentially
        testBirthdayEasterEgg()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.testEngagementToggle()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.testMasterToggle()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.testSettingsManagerIntegration()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.testResetToDefaults()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.testResults.append("🏁 All tests completed!")
        }
    }
}

// MARK: - Preview

struct NotificationSystemTestView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationSystemTestView()
    }
}
