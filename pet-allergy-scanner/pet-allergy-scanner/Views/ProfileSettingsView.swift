//
//  ProfileSettingsView.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 10/1/25.
//

import SwiftUI

/// Unified profile and settings view for the pet allergy scanner app
/// Combines user profile information with comprehensive settings management
/// Provides access to account management, pet preferences, scan settings, privacy controls, and app configuration
struct ProfileSettingsView: View {
    // MARK: - Settings Manager
    @StateObject private var settingsManager = SettingsManager.shared
    
    // MARK: - State Properties
    @State private var showingClearCacheAlert = false
    @State private var showingResetSettingsAlert = false
    @State private var showingSignOutAlert = false
    @State private var showingDeleteAccountAlert = false
    @State private var cacheSize = "0 MB"
    @State private var showingMFASetup = false
    @State private var showingGDPRView = false
    @State private var showingSubscriptionView = false
    @State private var showingEditProfile = false
    
    // MARK: - Service Dependencies
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var petService: PetService
    @StateObject private var mfaService = MFAService.shared
    @StateObject private var gdprService = GDPRService.shared
    @StateObject private var analyticsManager = AnalyticsManager.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Profile Header Section
                profileHeaderSection
                
                // MARK: - Settings Form
                Form {
                    // MARK: - Account Section
                    accountSection
                    
                    // MARK: - Pet Management Section
                    petManagementSection
                    
                    // MARK: - Scan Preferences Section
                    scanPreferencesSection
                    
                    // MARK: - Privacy & Security Section
                    privacySecuritySection
                    
                    // MARK: - App Settings Section
                    appSettingsSection
                    
                    // MARK: - Data Management Section
                    dataManagementSection
                    
                    // MARK: - Support & Help Section
                    supportHelpSection
                    
                    // MARK: - About Section
                    aboutSection
                    
                    // MARK: - Debug Section (only in debug builds)
                    #if DEBUG
                    debugSection
                    #endif
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle("Profile & Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                calculateCacheSize()
                Task {
                    await mfaService.checkMFAStatus()
                }
            }
            .sheet(isPresented: $showingMFASetup) {
                MFASetupView()
                    .environmentObject(mfaService)
            }
            .sheet(isPresented: $showingGDPRView) {
                GDPRView()
                    .environmentObject(gdprService)
            }
            .sheet(isPresented: $showingSubscriptionView) {
                SubscriptionView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
                    .environmentObject(authService)
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
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authService.logout()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteAccount()
                    }
                }
            } message: {
                Text("This will permanently delete your account and all associated data. This action cannot be undone.")
            }
        }
        .trackScreen("ProfileSettings")
    }
    
    // MARK: - Profile Header Section
    private var profileHeaderSection: some View {
        VStack(spacing: 16) {
            // Profile Picture or Default Icon
            RemoteImageView(userImageUrl: authService.currentUser?.imageUrl)
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .overlay(Circle().stroke(ModernDesignSystem.Colors.primary, lineWidth: 3))
                .onAppear {
                    print("🔍 ProfileSettingsView: User data - imageUrl: \(authService.currentUser?.imageUrl ?? "nil")")
                    print("🔍 ProfileSettingsView: Full user data: \(authService.currentUser?.description ?? "nil")")
                }
            
            if let user = authService.currentUser {
                Text("\(user.firstName ?? "") \(user.lastName ?? "")")
                    .font(ModernDesignSystem.Typography.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text(user.email)
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Text(user.role.displayName)
                    .font(ModernDesignSystem.Typography.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(user.role == .premium ? ModernDesignSystem.Colors.goldenYellow : ModernDesignSystem.Colors.lightGray)
                    .foregroundColor(user.role == .premium ? ModernDesignSystem.Colors.textOnAccent : ModernDesignSystem.Colors.textPrimary)
                    .cornerRadius(12)
            } else {
                Text("No user data available")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 20)
        .background(ModernDesignSystem.Colors.surfaceVariant)
    }
    
    // MARK: - Account Section
    private var accountSection: some View {
        Section(header: Text("Account")) {
            // Edit Profile
            Button(action: { showingEditProfile = true }) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                    Text("Edit Profile")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Subscription
            Button(action: { showingSubscriptionView = true }) {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
                    Text("Subscription")
                    Spacer()
                    Text(authService.currentUser?.role.rawValue.capitalized ?? "Free")
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Multi-Factor Authentication
            Button(action: { showingMFASetup = true }) {
                HStack {
                    Image(systemName: mfaService.isMFAEnabled ? "checkmark.shield.fill" : "shield")
                        .foregroundColor(mfaService.isMFAEnabled ? ModernDesignSystem.Colors.safe : ModernDesignSystem.Colors.textSecondary)
                    Text("Two-Factor Authentication")
                    Spacer()
                    Text(mfaService.isMFAEnabled ? "Enabled" : "Disabled")
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Sign Out
            Button(action: { showingSignOutAlert = true }) {
                HStack {
                    Image(systemName: "arrow.right.square")
                        .foregroundColor(ModernDesignSystem.Colors.error)
                    Text("Sign Out")
                        .foregroundColor(ModernDesignSystem.Colors.error)
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Pet Management Section
    private var petManagementSection: some View {
        Section(header: Text("Pet Management")) {
            // Default Pet Selection
            if !petService.pets.isEmpty {
                Picker("Default Pet for Scans", selection: $settingsManager.defaultPetId) {
                    Text("None").tag(nil as String?)
                    ForEach(petService.pets) { pet in
                        Text(pet.name).tag(pet.id as String?)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            } else {
                HStack {
                    Image(systemName: "pawprint")
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    Text("No pets added yet")
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    Spacer()
                    NavigationLink("Add Pet", destination: AddPetView())
                        .font(ModernDesignSystem.Typography.caption)
                }
            }
            
            // Pet Count
            HStack {
                Text("Total Pets")
                Spacer()
                Text("\(petService.pets.count)")
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
        }
    }
    
    // MARK: - Scan Preferences Section
    private var scanPreferencesSection: some View {
        Section(header: Text("Scan Preferences")) {
            // Camera Quality
            Picker("Image Quality", selection: $settingsManager.cameraResolution) {
                Text("Low (Faster)").tag("low")
                Text("Medium (Balanced)").tag("medium")
                Text("High (Best)").tag("high")
            }
            .pickerStyle(MenuPickerStyle())
            
            // Auto-save Scans
            Toggle("Auto-save Scans", isOn: $settingsManager.scanAutoSave)
                .tint(ModernDesignSystem.Colors.primary)
            
            // Auto Analysis
            Toggle("Auto-analyze Ingredients", isOn: $settingsManager.enableAutoAnalysis)
                .tint(ModernDesignSystem.Colors.primary)
            
            // Detailed Reports
            Toggle("Detailed Safety Reports", isOn: $settingsManager.enableDetailedReports)
                .tint(ModernDesignSystem.Colors.primary)
            
            // Scan History
            HStack {
                Text("Scan History")
                Spacer()
                Text("\(ScanService.shared.recentScans.count) scans")
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
        }
    }
    
    // MARK: - Privacy & Security Section
    private var privacySecuritySection: some View {
        Section(header: Text("Privacy & Security")) {
            // Analytics
            Toggle("Analytics & Usage Data", isOn: $settingsManager.enableAnalytics)
                .tint(ModernDesignSystem.Colors.primary)
                .onChange(of: settingsManager.enableAnalytics) { _, newValue in
                    analyticsManager.setAnalyticsEnabled(newValue)
                }
            
            // GDPR Controls
            Button(action: { showingGDPRView = true }) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                    Text("Data & Privacy Controls")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Camera Permissions
            NavigationLink(destination: CameraPermissionsView()) {
                HStack {
                    Image(systemName: "camera.fill")
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                    Text("Camera Permissions")
                }
            }
            
            // Notification Settings
            NavigationLink(destination: NotificationSettingsView()) {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                    Text("Notification Settings")
                }
            }
        }
    }
    
    // MARK: - App Settings Section
    private var appSettingsSection: some View {
        Section(header: Text("App Settings")) {
            // Notifications
            Toggle("Push Notifications", isOn: $settingsManager.enableNotifications)
                .tint(ModernDesignSystem.Colors.primary)
            
            // Haptic Feedback
            Toggle("Haptic Feedback", isOn: $settingsManager.enableHapticFeedback)
                .tint(ModernDesignSystem.Colors.primary)
            
            // Dark Mode
            HStack {
                Image(systemName: "moon.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                Text("Dark Mode")
                Spacer()
                Text("System")
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
        }
    }
    
    // MARK: - Data Management Section
    private var dataManagementSection: some View {
        Section(header: Text("Data Management")) {
            // Cache Size
            HStack {
                Text("Cache Size")
                Spacer()
                Text(cacheSize)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            // Clear Cache
            Button(action: { showingClearCacheAlert = true }) {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(ModernDesignSystem.Colors.error)
                    Text("Clear Cache")
                        .foregroundColor(ModernDesignSystem.Colors.error)
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Reset Settings
            Button(action: { showingResetSettingsAlert = true }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(ModernDesignSystem.Colors.error)
                    Text("Reset Settings")
                        .foregroundColor(ModernDesignSystem.Colors.error)
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Support & Help Section
    private var supportHelpSection: some View {
        Section(header: Text("Support & Help")) {
            // Help Center
            NavigationLink(destination: HelpCenterView()) {
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                    Text("Help Center")
                }
            }
            
            // Contact Support
            NavigationLink(destination: ContactSupportView()) {
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                    Text("Contact Support")
                }
            }
            
            // Rate App
            Button(action: rateApp) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
                    Text("Rate App")
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - About Section
    private var aboutSection: some View {
        Section(header: Text("About")) {
            // App Version
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.appVersion)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            // Build Number
            HStack {
                Text("Build")
                Spacer()
                Text(Bundle.main.buildNumber)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            // Terms of Service
            NavigationLink(destination: TermsOfServiceView()) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    Text("Terms of Service")
                }
            }
            
            // Privacy Policy
            NavigationLink(destination: PrivacyPolicyView()) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    Text("Privacy Policy")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
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
        settingsManager.resetToDefaults()
    }
    
    /// Delete user account and all associated data
    private func deleteAccount() async {
        let success = await gdprService.deleteUserData()
        if success {
            // Account deletion handled by GDPRService
            HapticFeedback.success()
        } else {
            HapticFeedback.error()
        }
    }
    
    /// Open App Store rating page
    private func rateApp() {
        if let url = URL(string: "https://apps.apple.com/app/id1234567890") {
            UIApplication.shared.open(url)
        }
    }
    
    /// Share the app with others
    private func shareApp() {
        let activityViewController = UIActivityViewController(
            activityItems: ["Check out Pet Allergy Scanner - keep your pets safe!"],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityViewController, animated: true)
        }
    }
}

// MARK: - Supporting Views

/// View for camera permissions management
struct CameraPermissionsView: View {
    @State private var permissionStatus = "Unknown"
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(ModernDesignSystem.Colors.primary)
            
            Text("Camera Permissions")
                .font(ModernDesignSystem.Typography.title2)
            
            Text("Camera access is required to scan ingredient labels. You can manage permissions in your device settings.")
                .font(ModernDesignSystem.Typography.body)
                .multilineTextAlignment(.center)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            Button("Open Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            .modernButton(style: .primary)
            
            Spacer()
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .navigationTitle("Camera Permissions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// View for notification settings management
struct NotificationSettingsView: View {
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            Image(systemName: "bell.fill")
                .font(.system(size: 60))
                .foregroundColor(ModernDesignSystem.Colors.primary)
            
            Text("Notification Settings")
                .font(ModernDesignSystem.Typography.title2)
            
            Text("Manage your notification preferences to stay updated about scan results and app updates.")
                .font(ModernDesignSystem.Typography.body)
                .multilineTextAlignment(.center)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            Button("Open Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            .modernButton(style: .primary)
            
            Spacer()
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// View for help center
struct HelpCenterView: View {
    var body: some View {
        List {
            Section("Getting Started") {
                HelpItem(title: "How to Add a Pet", description: "Learn how to create a pet profile")
                HelpItem(title: "How to Scan Ingredients", description: "Step-by-step scanning guide")
                HelpItem(title: "Understanding Results", description: "What the safety ratings mean")
            }
            
            Section("Troubleshooting") {
                HelpItem(title: "Camera Not Working", description: "Fix camera issues")
                HelpItem(title: "Scan Not Accurate", description: "Improve scan quality")
                HelpItem(title: "App Crashes", description: "Common crash solutions")
            }
            
            Section("Account & Privacy") {
                HelpItem(title: "Account Settings", description: "Manage your account")
                HelpItem(title: "Data Privacy", description: "How we protect your data")
                HelpItem(title: "Delete Account", description: "Remove your account")
            }
        }
        .navigationTitle("Help Center")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Help item component
struct HelpItem: View {
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
            Text(title)
                .font(ModernDesignSystem.Typography.bodyEmphasized)
            Text(description)
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
        }
        .padding(.vertical, ModernDesignSystem.Spacing.xs)
    }
}

/// View for contact support
struct ContactSupportView: View {
    @State private var message = ""
    @State private var showingEmail = false
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 60))
                .foregroundColor(ModernDesignSystem.Colors.primary)
            
            Text("Contact Support")
                .font(ModernDesignSystem.Typography.title2)
            
            Text("Need help? We're here to assist you with any questions or issues.")
                .font(ModernDesignSystem.Typography.body)
                .multilineTextAlignment(.center)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                Button("Email Support") {
                    showingEmail = true
                }
                .modernButton(style: .primary)
            }
            
            Spacer()
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .navigationTitle("Contact Support")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEmail) {
            EmailSupportView()
        }
    }
}

/// View for email support
struct EmailSupportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var subject = ""
    @State private var message = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Subject") {
                    TextField("Brief description of your issue", text: $subject)
                }
                
                Section("Message") {
                    TextField("Please describe your issue in detail...", text: $message, axis: .vertical)
                        .lineLimit(5...10)
                }
            }
            .navigationTitle("Email Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") {
                        sendEmail()
                    }
                    .disabled(subject.isEmpty || message.isEmpty)
                }
            }
        }
    }
    
    private func sendEmail() {
        // Implement email sending
        dismiss()
    }
}

/// View for terms of service
struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
                Text("Terms of Service")
                    .font(ModernDesignSystem.Typography.title)
                
                Text("Last updated: January 1, 2025")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Text("By using Pet Allergy Scanner, you agree to these terms...")
                    .font(ModernDesignSystem.Typography.body)
                
                // Add full terms content here
            }
            .padding(ModernDesignSystem.Spacing.lg)
        }
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// View for privacy policy
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
                Text("Privacy Policy")
                    .font(ModernDesignSystem.Typography.title)
                
                Text("Last updated: January 1, 2025")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Text("We respect your privacy and are committed to protecting your personal data...")
                    .font(ModernDesignSystem.Typography.body)
                
                // Add full privacy policy content here
            }
            .padding(ModernDesignSystem.Spacing.lg)
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ProfileSettingsView()
        .environmentObject(AuthService.shared)
        .environmentObject(PetService.shared)
}
