//
//  NotificationTestView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

/// Test view for demonstrating notification system functionality
/// This view can be used during development to test different notification scenarios
struct NotificationTestView: View {
    @StateObject private var notificationSettingsManager = NotificationSettingsManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var petService = CachedPetService.shared
    @State private var mealReminderService = MealReminderService.shared
    @State private var medicationReminderService = MedicationReminderService.shared
    @State private var pushNotificationService = PushNotificationService.shared
    @State private var showingBirthdayCelebration = false
    @State private var testPet: Pet?
    @State private var testMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                Section("Notification Status") {
                    HStack {
                        Image(systemName: notificationSettingsManager.isAuthorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(notificationSettingsManager.isAuthorized ? .green : .orange)
                        Text(notificationSettingsManager.isAuthorized ? "Authorized" : "Not Authorized")
                    }
                    
                    HStack {
                        Image(systemName: pushNotificationService.isAuthorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(pushNotificationService.isAuthorized ? .green : .orange)
                        Text("Push Notifications: \(pushNotificationService.isAuthorized ? "Authorized" : "Not Authorized")")
                    }
                    
                    if let token = pushNotificationService.deviceToken {
                        VStack(alignment: .leading) {
                            Text("Device Token:")
                                .font(.caption)
                            Text(token.prefix(40) + "...")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if !testMessage.isEmpty {
                    Section("Test Result") {
                        Text(testMessage)
                            .foregroundColor(testMessage.hasPrefix("✅") ? .green : testMessage.hasPrefix("❌") ? .red : .blue)
                    }
                }
                
                Section("Test Notifications - Immediate (2 seconds)") {
                    Button("🔔 Test Local Notification (Banner)") {
                        testImmediateNotification()
                    }
                    .disabled(!notificationSettingsManager.isAuthorized)
                    
                    Button("🎉 Test Birthday Notification") {
                        scheduleTestBirthdayNotification()
                    }
                    .disabled(!notificationSettingsManager.isAuthorized)
                    
                    Button("🔍 Test Engagement Notification") {
                        scheduleTestEngagementNotification()
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
                }
                
                Section("Test Push Notifications") {
                    HStack {
                        Text("Device Token")
                        Spacer()
                        if let token = PushNotificationService.shared.deviceToken {
                            Text(token.prefix(20) + "...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Not registered")
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Button("📱 Test Push Notification") {
                        Task {
                            await testPushNotification()
                        }
                    }
                    .disabled(!PushNotificationService.shared.isAuthorized || PushNotificationService.shared.deviceToken == nil)
                }
                
                Section("Test Features") {
                    Button("Test Birthday Celebration") {
                        testBirthdayCelebration()
                    }
                    .disabled(petService.pets.isEmpty)
                    
                    Button("Test Engagement Reminder") {
                        testEngagementReminder()
                    }
                    
                    Button("Check Meal Reminders Now") {
                        Task {
                            await testMealReminderCheck()
                        }
                    }
                }
                
                Section("Pet Data") {
                    if petService.pets.isEmpty {
                        Text("No pets available for testing")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(petService.pets) { pet in
                            VStack(alignment: .leading) {
                                Text(pet.name)
                                    .font(.headline)
                                if let birthday = pet.birthday {
                                    Text("Birthday: \(birthday, style: .date)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("No birthday set")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                Section("Notification Settings") {
                    HStack {
                        Text("Birthday Surprises")
                        Spacer()
                        Text("Easter Egg")
                            .foregroundColor(.yellow)
                    }
                    Toggle("Engagement Notifications", isOn: $notificationSettingsManager.engagementNotificationsEnabled)
                }
                
                Section("Actions") {
                    Button("Request Permission") {
                        Task {
                            await notificationSettingsManager.requestPermission()
                        }
                    }
                    
                    Button("Schedule All Notifications") {
                        notificationSettingsManager.scheduleAllNotifications()
                    }
                    .disabled(!notificationSettingsManager.isAuthorized)
                    
                    Button("Cancel All Notifications") {
                        notificationSettingsManager.cancelAllNotifications()
                    }
                }
            }
            .navigationTitle("Notification Test")
            .onAppear {
                petService.loadPets()
            }
        }
        .sheet(isPresented: $showingBirthdayCelebration) {
            if let pet = testPet {
                BirthdayCelebrationView(pet: pet, isPresented: $showingBirthdayCelebration)
            }
        }
    }
    
    // MARK: - Test Methods
    
    private func testBirthdayCelebration() {
        guard let pet = petService.pets.first else { return }
        testPet = pet
        showingBirthdayCelebration = true
    }
    
    private func testEngagementReminder() {
        notificationManager.checkEngagementStatus()
    }
    
    private func scheduleTestBirthdayNotification() {
        let content = UNMutableNotificationContent()
        content.title = "🎉 Test Birthday Notification"
        content.body = "This is a test birthday notification!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test_birthday_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule test birthday notification: \(error)")
            } else {
                print("✅ Test birthday notification scheduled")
            }
        }
    }
    
    private func scheduleTestEngagementNotification() {
        let content = UNMutableNotificationContent()
        content.title = "🔍 Test Engagement Notification"
        content.body = "This is a test engagement notification! Check your notification bar."
        content.sound = .default
        content.badge = 1
        
        // Schedule for 2 seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test_engagement_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule test engagement notification: \(error)")
            } else {
                print("✅ Test engagement notification scheduled - will appear in 2 seconds")
            }
        }
    }
    
    /**
     * Test immediate notification to verify it appears in notification bar
     */
    private func testImmediateNotification() {
        let content = UNMutableNotificationContent()
        content.title = "🔔 Test Notification"
        content.body = "This should appear in your notification bar right now! Look at the top of your screen."
        content.sound = .default
        content.badge = 1
        
        // Schedule for 2 seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test_immediate_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            Task { @MainActor in
                if let error = error {
                    print("❌ Failed to schedule test notification: \(error)")
                    testMessage = "❌ Error: \(error.localizedDescription)"
                } else {
                    print("✅ Test notification scheduled - will appear in 2 seconds in notification bar")
                    testMessage = "✅ Notification scheduled! Check notification bar in 2 seconds."
                }
            }
        }
    }
    
    /**
     * Test meal reminder notification
     */
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
        
        // Schedule for 2 seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test_meal_reminder_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            Task { @MainActor in
                if let error = error {
                    print("❌ Failed to schedule test meal reminder: \(error)")
                    testMessage = "❌ Error: \(error.localizedDescription)"
                } else {
                    print("✅ Test meal reminder scheduled - will appear in 2 seconds")
                    testMessage = "✅ Meal reminder scheduled for \(pet.name)! Check notification bar in 2 seconds."
                }
            }
        }
    }
    
    /**
     * Test medication reminder notification
     */
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
        
        // Schedule for 2 seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test_medication_reminder_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            Task { @MainActor in
                if let error = error {
                    print("❌ Failed to schedule test medication reminder: \(error)")
                    testMessage = "❌ Error: \(error.localizedDescription)"
                } else {
                    print("✅ Test medication reminder scheduled - will appear in 2 seconds")
                    testMessage = "✅ Medication reminder scheduled! Check notification bar in 2 seconds."
                }
            }
        }
    }
    
    /**
     * Test meal reminder check functionality
     */
    private func testMealReminderCheck() async {
        testMessage = "🔄 Checking meal logs..."
        await mealReminderService.checkAndSendMealReminders()
        testMessage = "✅ Meal reminder check completed! Notifications sent if needed."
    }
    
    /**
     * Test push notification sending
     */
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
            print("✅ Push notification sent successfully")
        } catch {
            testMessage = "❌ Failed to send push notification: \(error.localizedDescription)"
            print("❌ Failed to send push notification: \(error)")
        }
    }
}

// MARK: - Preview

struct NotificationTestView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationTestView()
    }
}
