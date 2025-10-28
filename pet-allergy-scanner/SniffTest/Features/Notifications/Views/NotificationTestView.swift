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
    @State private var showingBirthdayCelebration = false
    @State private var testPet: Pet?
    
    var body: some View {
        NavigationView {
            List {
                Section("Notification Status") {
                    HStack {
                        Image(systemName: notificationSettingsManager.isAuthorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(notificationSettingsManager.isAuthorized ? .green : .orange)
                        Text(notificationSettingsManager.isAuthorized ? "Authorized" : "Not Authorized")
                    }
                }
                
                Section("Test Notifications") {
                    Button("Test Birthday Celebration") {
                        testBirthdayCelebration()
                    }
                    .disabled(petService.pets.isEmpty)
                    
                    Button("Test Engagement Reminder") {
                        testEngagementReminder()
                    }
                    
                    Button("Schedule Test Birthday Notification") {
                        scheduleTestBirthdayNotification()
                    }
                    .disabled(!notificationSettingsManager.isAuthorized)
                    
                    Button("Schedule Test Engagement Notification") {
                        scheduleTestEngagementNotification()
                    }
                    .disabled(!notificationSettingsManager.isAuthorized)
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
        content.body = "This is a test engagement notification!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test_engagement_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule test engagement notification: \(error)")
            } else {
                print("✅ Test engagement notification scheduled")
            }
        }
    }
}

// MARK: - Preview

struct NotificationTestView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationTestView()
    }
}
