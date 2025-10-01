//
//  SettingsView.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 10/1/25.
//

import SwiftUI

/// View for app settings and preferences
struct SettingsView: View {
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("enableHapticFeedback") private var enableHapticFeedback = true
    @AppStorage("enableAnalytics") private var enableAnalytics = true
    @AppStorage("scanAutoSave") private var scanAutoSave = true
    @AppStorage("preferredLanguage") private var preferredLanguage = "en"
    @AppStorage("cameraResolution") private var cameraResolution = "high"
    
    @State private var showingClearCacheAlert = false
    @State private var showingResetSettingsAlert = false
    @State private var cacheSize = "0 MB"
    
    var body: some View {
        NavigationStack {
            Form {
                // General Settings
                Section(header: Text("General")) {
                    Toggle("Enable Notifications", isOn: $enableNotifications)
                        .tint(ModernDesignSystem.Colors.deepForestGreen)
                    
                    Toggle("Haptic Feedback", isOn: $enableHapticFeedback)
                        .tint(ModernDesignSystem.Colors.deepForestGreen)
                    
                    Picker("Language", selection: $preferredLanguage) {
                        Text("English").tag("en")
                        Text("Spanish").tag("es")
                        Text("French").tag("fr")
                        Text("German").tag("de")
                    }
                }
                
                // Camera Settings
                Section(header: Text("Camera")) {
                    Picker("Image Quality", selection: $cameraResolution) {
                        Text("Low").tag("low")
                        Text("Medium").tag("medium")
                        Text("High").tag("high")
                    }
                    
                    Toggle("Auto-save Scans", isOn: $scanAutoSave)
                        .tint(ModernDesignSystem.Colors.deepForestGreen)
                }
                
                // Privacy Settings
                Section(header: Text("Privacy")) {
                    Toggle("Analytics", isOn: $enableAnalytics)
                        .tint(ModernDesignSystem.Colors.deepForestGreen)
                    
                    NavigationLink(destination: Text("Camera Permissions").navigationTitle("Permissions")) {
                        HStack {
                            Image(systemName: "camera")
                            Text("Camera Permissions")
                        }
                    }
                    
                    NavigationLink(destination: Text("Notifications").navigationTitle("Notifications")) {
                        HStack {
                            Image(systemName: "bell")
                            Text("Notification Settings")
                        }
                    }
                }
                
                // Data Management
                Section(header: Text("Data Management")) {
                    HStack {
                        Text("Cache Size")
                        Spacer()
                        Text(cacheSize)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    
                    Button(action: {
                        showingClearCacheAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear Cache")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // Advanced Settings
                Section(header: Text("Advanced")) {
                    NavigationLink(destination: Text("Debug").navigationTitle("Debug")) {
                        HStack {
                            Image(systemName: "ladybug")
                            Text("Debug Options")
                        }
                    }
                    
                    Button(action: {
                        showingResetSettingsAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset Settings")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // About Section
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.appVersion)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.buildNumber)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                calculateCacheSize()
            }
            .alert("Clear Cache", isPresented: $showingClearCacheAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearCache()
                }
            } message: {
                Text("This will clear all cached data including images and temporary files.")
            }
            .alert("Reset Settings", isPresented: $showingResetSettingsAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetSettings()
                }
            } message: {
                Text("This will reset all settings to their default values.")
            }
        }
    }
    
    /// Calculate total cache size
    private func calculateCacheSize() {
        DispatchQueue.global(qos: .utility).async {
            let fileManager = FileManager.default
            
            guard let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
                return
            }
            
            var totalSize: Int64 = 0
            
            if let enumerator = fileManager.enumerator(at: cachesURL, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let fileURL as URL in enumerator {
                    if let fileAttributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                       let fileSize = fileAttributes[.size] as? Int64 {
                        totalSize += fileSize
                    }
                }
            }
            
            let sizeInMB = Double(totalSize) / 1024.0 / 1024.0
            
            DispatchQueue.main.async {
                cacheSize = String(format: "%.2f MB", sizeInMB)
            }
        }
    }
    
    /// Clear all cached data
    private func clearCache() {
        let fileManager = FileManager.default
        
        guard let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return
        }
        
        do {
            let cacheFiles = try fileManager.contentsOfDirectory(at: cachesURL, includingPropertiesForKeys: nil)
            
            for file in cacheFiles {
                try fileManager.removeItem(at: file)
            }
            
            HapticFeedback.success()
            calculateCacheSize()
        } catch {
            print("Failed to clear cache: \(error)")
            HapticFeedback.error()
        }
    }
    
    /// Reset all settings to default values
    private func resetSettings() {
        enableNotifications = true
        enableHapticFeedback = true
        enableAnalytics = true
        scanAutoSave = true
        preferredLanguage = "en"
        cameraResolution = "high"
        
        HapticFeedback.success()
    }
}

#Preview {
    SettingsView()
}

