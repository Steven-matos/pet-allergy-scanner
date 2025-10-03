//
//  NotificationSettingsView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

/// Notification settings view for managing user notification preferences
/// Allows users to enable/disable different types of notifications
struct NotificationSettingsView: View {
    @StateObject private var notificationSettingsManager = NotificationSettingsManager.shared
    @State private var showingPermissionAlert = false
    @State private var permissionAlertMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                // Permission Status Section
                permissionStatusSection
                
                // Notification Types Section
                notificationTypesSection
                
                // Engagement Settings Section
                engagementSettingsSection
                
                // Test Notifications Section
                testNotificationsSection
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .alert("Notification Permission Required", isPresented: $showingPermissionAlert) {
                Button("Settings") {
                    openAppSettings()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(permissionAlertMessage)
            }
            .onAppear {
                Task {
                    await notificationSettingsManager.checkAuthorizationStatus()
                }
            }
        }
    }
    
    // MARK: - Permission Status Section
    
    private var permissionStatusSection: some View {
        Section {
            HStack {
                Image(systemName: notificationSettingsManager.isAuthorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(notificationSettingsManager.isAuthorized ? .green : .orange)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(notificationSettingsManager.isAuthorized ? "Notifications Enabled" : "Notifications Disabled")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(notificationSettingsManager.isAuthorized ? 
                         "You'll receive birthday reminders and engagement notifications." :
                         "Enable notifications to get birthday reminders and engagement updates.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
            
            if !notificationSettingsManager.isAuthorized {
                Button("Enable Notifications") {
                    requestNotificationPermission()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        } header: {
            Text("Status")
        }
    }
    
    // MARK: - Notification Types Section
    
    private var notificationTypesSection: some View {
        Section {
            // Birthday Easter Egg Info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "gift.fill")
                            .foregroundColor(.pink)
                        Text("Birthday Surprises")
                            .font(.headline)
                    }
                    
                    Text("Surprise birthday celebrations during your pet's birth month! 🎉")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                    .font(.title2)
            }
            .padding(.vertical, 4)
            
            // Engagement Notifications
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("Engagement Reminders")
                            .font(.headline)
                    }
                    
                    Text("Gentle reminders to keep your pet's health monitoring active")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $notificationSettingsManager.engagementNotificationsEnabled)
                    .onChange(of: notificationSettingsManager.engagementNotificationsEnabled) { _, _ in
                        // Toggle is handled automatically by the @Published property
                    }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Notification Types")
        } footer: {
            Text("Customize which types of notifications you'd like to receive. All notifications respect your device's Do Not Disturb settings.")
        }
    }
    
    // MARK: - Engagement Settings Section
    
    private var engagementSettingsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                    Text("Engagement Schedule")
                        .font(.headline)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Weekly Reminder")
                            .font(.subheadline)
                        Spacer()
                        Text("7 days")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Monthly Check-in")
                            .font(.subheadline)
                        Spacer()
                        Text("30 days")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.leading, 24)
            }
            .padding(.vertical, 8)
            
            if let lastScanDate = notificationSettingsManager.lastScanDate {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Scan Activity")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(lastScanDate, style: .relative)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Engagement Settings")
        } footer: {
            Text("We'll send gentle reminders if you haven't scanned any pet food in a while. This helps ensure your pet's safety.")
        }
    }
    
    // MARK: - Test Notifications Section
    
    private var testNotificationsSection: some View {
        Section {
            Button("Test Birthday Notification") {
                testBirthdayNotification()
            }
            .disabled(!notificationSettingsManager.isAuthorized)
            
            Button("Test Engagement Notification") {
                testEngagementNotification()
            }
            .disabled(!notificationSettingsManager.isAuthorized)
        } header: {
            Text("Test Notifications")
        } footer: {
            Text("Test how notifications will appear on your device. Make sure notifications are enabled for this app in Settings.")
        }
    }
    
    // MARK: - Private Methods
    
    private func requestNotificationPermission() {
        Task {
            let granted = await notificationSettingsManager.requestPermission()
            if !granted {
                permissionAlertMessage = "To receive notifications, please enable them in Settings > Notifications > Pet Allergy Scanner."
                showingPermissionAlert = true
            }
        }
    }
    
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func testBirthdayNotification() {
        // Create a test notification
        let content = UNMutableNotificationContent()
        content.title = "🎉 Test Birthday Notification"
        content.body = "This is how birthday notifications will appear!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test_birthday",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule test notification: \(error)")
            }
        }
    }
    
    private func testEngagementNotification() {
        // Create a test notification
        let content = UNMutableNotificationContent()
        content.title = "🔍 Test Engagement Notification"
        content.body = "This is how engagement reminders will appear!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test_engagement",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule test notification: \(error)")
            }
        }
    }
}

// MARK: - Preview

struct NotificationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationSettingsView()
    }
}
