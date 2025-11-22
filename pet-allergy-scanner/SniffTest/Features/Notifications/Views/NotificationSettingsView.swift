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
    @State private var mealReminderService = MealReminderService.shared
    @State private var pushNotificationService = PushNotificationService.shared
    @State private var petService = CachedPetService.shared
    @State private var showingPermissionAlert = false
    @State private var showingTestView = false
    @State private var permissionAlertMessage = ""
    @State private var testMessage = ""
    
    var body: some View {
        List {
            // Permission Status Section
            permissionStatusSection
            
            // Notification Types Section
            notificationTypesSection
            
            // Engagement Settings Section
            engagementSettingsSection
            
            // Test Notifications Section
            testNotificationsSection
            
            // Advanced Testing Section
            advancedTestingSection
        }
        .navigationTitle("Notification Settings")
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
                petService.loadPets()
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
            Button("🔔 Test Local Notification (2s delay)") {
                testImmediateNotification()
            }
            .disabled(!notificationSettingsManager.isAuthorized)
            
            Button("🎉 Test Birthday Notification") {
                testBirthdayNotification()
            }
            .disabled(!notificationSettingsManager.isAuthorized)
            
            Button("🔍 Test Engagement Notification") {
                testEngagementNotification()
            }
            .disabled(!notificationSettingsManager.isAuthorized)
            
            Button("🍽️ Test Meal Reminder") {
                testMealReminder()
            }
            .disabled(!notificationSettingsManager.isAuthorized || petService.pets.isEmpty)
            
            Button("💊 Test Medication Reminder") {
                testMedicationReminder()
            }
            .disabled(!notificationSettingsManager.isAuthorized || petService.pets.isEmpty)
        } header: {
            Text("Test Notifications (2 seconds)")
        } footer: {
            if !testMessage.isEmpty {
                Text(testMessage)
                    .foregroundColor(testMessage.hasPrefix("✅") ? .green : testMessage.hasPrefix("❌") ? .red : .blue)
            } else {
                Text("Test how notifications will appear on your device. Make sure notifications are enabled for this app in Settings.")
            }
        }
    }
    
    // MARK: - Advanced Testing Section
    
    private var advancedTestingSection: some View {
        Section {
            NavigationLink(destination: NotificationTestView()) {
                HStack {
                    Image(systemName: "testtube.2")
                        .foregroundColor(.blue)
                    Text("Advanced Notification Testing")
                }
            }
            
            Button("Check Meal Reminders Now") {
                Task {
                    await checkMealRemindersNow()
                }
            }
            .disabled(petService.pets.isEmpty)
            
            if pushNotificationService.deviceToken != nil {
                Button("📱 Test Push Notification") {
                    Task {
                        await testPushNotification()
                    }
                }
                .disabled(!pushNotificationService.isAuthorized)
            }
        } header: {
            Text("Advanced Testing")
        } footer: {
            Text("Use these tools to test meal and medication reminder functionality.")
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
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test_engagement",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            Task { @MainActor in
                if let error = error {
                    print("❌ Failed to schedule test notification: \(error)")
                    testMessage = "❌ Error: \(error.localizedDescription)"
                } else {
                    testMessage = "✅ Notification scheduled! Check notification bar in 2 seconds."
                }
            }
        }
    }
    
    private func testImmediateNotification() {
        let content = UNMutableNotificationContent()
        content.title = "🔔 Test Notification"
        content.body = "This should appear in your notification bar! Look at the top of your screen."
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test_immediate_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            Task { @MainActor in
                if let error = error {
                    testMessage = "❌ Error: \(error.localizedDescription)"
                } else {
                    testMessage = "✅ Notification scheduled! Check notification bar in 2 seconds."
                }
            }
        }
    }
    
    private func testMealReminder() {
        guard let pet = petService.pets.first else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🍽️ Don't Forget to Log \(pet.name)'s Meal!"
        content.body = "You haven't logged any meals for \(pet.name) today. Tap to log their meal now."
        content.sound = .default
        content.badge = 1
        content.userInfo = [
            "type": "meal_reminder",
            "pet_id": pet.id,
            "pet_name": pet.name,
            "action": "log_meal"
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test_meal_reminder_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            Task { @MainActor in
                if let error = error {
                    testMessage = "❌ Error: \(error.localizedDescription)"
                } else {
                    testMessage = "✅ Meal reminder scheduled for \(pet.name)! Check notification bar in 2 seconds."
                }
            }
        }
    }
    
    private func testMedicationReminder() {
        guard let pet = petService.pets.first else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "💊 Medication Reminder"
        content.body = "Time to give Heartworm Prevention (1 tablet) to \(pet.name)"
        content.sound = .default
        content.badge = 1
        content.userInfo = [
            "type": "medication_reminder",
            "medication_id": "test_med_id",
            "pet_id": pet.id,
            "medication_name": "Heartworm Prevention",
            "dosage": "1 tablet",
            "action": "view_medication"
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test_medication_reminder_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            Task { @MainActor in
                if let error = error {
                    testMessage = "❌ Error: \(error.localizedDescription)"
                } else {
                    testMessage = "✅ Medication reminder scheduled! Check notification bar in 2 seconds."
                }
            }
        }
    }
    
    private func checkMealRemindersNow() async {
        testMessage = "🔄 Checking meal logs..."
        await mealReminderService.checkAndSendMealReminders()
        testMessage = "✅ Meal reminder check completed! Notifications sent if needed."
    }
    
    private func testPushNotification() async {
        guard pushNotificationService.isAuthorized,
              let deviceToken = pushNotificationService.deviceToken else {
            testMessage = "❌ Push notifications not authorized or no device token"
            return
        }
        
        testMessage = "📱 Sending push notification..."
        
        let payload: [String: Any] = [
            "aps": [
                "alert": [
                    "title": "📱 Test Push Notification",
                    "body": "This is a test push notification sent via APNs! If you see this, push notifications are working!"
                ],
                "sound": "default",
                "badge": 1,
                "category": "test"
            ],
            "type": "test_notification",
            "action": "test"
        ]
        
        do {
            try await pushNotificationService.sendPushNotification(payload: payload, deviceToken: deviceToken)
            testMessage = "✅ Push notification sent! Check your phone in a few seconds."
        } catch {
            testMessage = "❌ Failed to send push notification: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preview

struct NotificationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationSettingsView()
    }
}
