//
//  MealReminderService.swift
//  SniffTest
//
//  Created by Steven Matos on 1/15/25.
//

import Foundation
import UserNotifications
import SwiftUI

/**
 * Meal Reminder Service
 * 
 * Manages meal logging reminders for pets
 * Sends notifications if meals haven't been logged for the day
 * Follows SOLID principles with single responsibility for meal reminders
 * Implements DRY by reusing common notification patterns
 * Follows KISS by keeping the reminder system simple and focused
 */
@MainActor
class MealReminderService: NSObject, ObservableObject {
    static let shared = MealReminderService()
    
    @Published var isEnabled = true
    @Published var reminderTime = DateComponents(hour: 18, minute: 0) // Default: 6 PM
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let feedingService = FeedingLogService.shared
    private let petService = CachedPetService.shared
    private let pushNotificationService = PushNotificationService.shared
    
    // MARK: - Constants
    
    private enum NotificationIdentifiers {
        static let mealReminderPrefix = "meal_reminder_"
        static let dailyCheck = "meal_reminder_daily_check"
    }
    
    private enum UserDefaultsKeys {
        static let mealRemindersEnabled = "meal_reminders_enabled"
        static let reminderTimeHour = "meal_reminder_time_hour"
        static let reminderTimeMinute = "meal_reminder_time_minute"
    }
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        loadSettings()
        scheduleDailyCheck()
    }
    
    // MARK: - Public Methods
    
    /**
     * Enable meal reminders
     */
    func enable() {
        isEnabled = true
        saveSettings()
        scheduleDailyCheck()
    }
    
    /**
     * Disable meal reminders
     */
    func disable() {
        isEnabled = false
        saveSettings()
        cancelAllMealReminders()
    }
    
    /**
     * Set the daily reminder time
     * - Parameter time: Time components for reminder (hour, minute)
     */
    func setReminderTime(_ time: DateComponents) {
        reminderTime = time
        saveSettings()
        scheduleDailyCheck()
    }
    
    /**
     * Check if meals were logged today for all pets and send reminders if needed
     * This is called by the daily scheduled notification
     */
    func checkAndSendMealReminders() async {
        guard isEnabled else { return }
        
        print("🍽️ Checking for meal logs today...")
        
        let today = Date()
        
        // Get all pets
        let pets = petService.pets
        
        guard !pets.isEmpty else {
            print("⚠️ No pets found - skipping meal reminder check")
            return
        }
        
        // Check each pet for today's meals
        for pet in pets {
            // First, try to load fresh feeding records for this pet
            do {
                _ = try await feedingService.getFeedingRecords(for: pet.id, days: 7)
            } catch {
                print("⚠️ Failed to load feeding records for \(pet.name): \(error)")
            }
            
            // Get feeding records for today
            let todayRecords = feedingService.getFeedingRecordsForDate(for: pet.id, date: today)
            
            print("📊 \(pet.name): \(todayRecords.count) meal(s) logged today")
            
            // If no meals logged today, send reminder
            if todayRecords.isEmpty {
                print("⚠️ No meals logged today for \(pet.name) - sending reminder")
                await sendMealReminder(for: pet)
            } else {
                print("✅ Meals logged today for \(pet.name) - no reminder needed")
            }
        }
    }
    
    /**
     * Check if meals were logged today for a specific pet
     * - Parameter petId: The pet's ID
     * - Returns: Boolean indicating if meals were logged today
     */
    func hasMealsLoggedToday(for petId: String) -> Bool {
        let today = Date()
        let todayRecords = feedingService.getFeedingRecordsForDate(for: petId, date: today)
        return !todayRecords.isEmpty
    }
    
    /**
     * Schedule daily check for meal reminders
     * This will check every day at the reminder time
     */
    func scheduleDailyCheck() {
        guard isEnabled else { return }
        
        // Cancel existing daily check
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [NotificationIdentifiers.dailyCheck])
        
        // Create content for the daily check trigger (silent notification that triggers check)
        let content = UNMutableNotificationContent()
        content.title = "Meal Reminder Check"
        content.body = "Checking for meal logs..."
        content.sound = nil // Silent notification
        content.badge = nil
        
        // Schedule daily at reminder time
        // Capture reminderTime values before closure to avoid main actor isolation issues
        let hour = reminderTime.hour ?? 18
        let minute = reminderTime.minute ?? 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: reminderTime, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: NotificationIdentifiers.dailyCheck,
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule daily meal reminder check: \(error)")
            } else {
                print("✅ Scheduled daily meal reminder check at \(hour):\(minute)")
            }
        }
    }
    
    /**
     * Cancel all meal reminders
     */
    func cancelAllMealReminders() {
        let allIdentifiers = petService.pets.map { "\(NotificationIdentifiers.mealReminderPrefix)\($0.id)" }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: allIdentifiers)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [NotificationIdentifiers.dailyCheck])
    }
    
    // MARK: - Private Methods
    
    /**
     * Send meal reminder notification for a pet
     * - Parameter pet: The pet to send reminder for
     */
    private func sendMealReminder(for pet: Pet) async {
        print("📱 Sending meal reminder for \(pet.name)")
        
        // Create local notification
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
        
        // Schedule immediate notification
        let request = UNNotificationRequest(
            identifier: "\(NotificationIdentifiers.mealReminderPrefix)\(pet.id)_\(UUID().uuidString)",
            content: content,
            trigger: nil // Immediate
        )
        
        do {
            try await notificationCenter.add(request)
            print("✅ Local meal reminder sent for \(pet.name)")
        } catch {
            print("❌ Failed to send local meal reminder: \(error)")
        }
        
        // Also send push notification if available
        if pushNotificationService.isAuthorized,
           let deviceToken = pushNotificationService.deviceToken {
            
            let payload: [String: Any] = [
                "aps": [
                    "alert": [
                        "title": "🍽️ Don't Forget to Log \(pet.name)'s Meal!",
                        "body": "You haven't logged any meals for \(pet.name) today. Tap to log their meal now."
                    ],
                    "sound": "default",
                    "badge": 1,
                    "category": "meal_reminder"
                ],
                "type": "meal_reminder",
                "pet_id": pet.id,
                "pet_name": pet.name,
                "action": "log_meal"
            ]
            
            do {
                try await pushNotificationService.sendPushNotification(payload: payload, deviceToken: deviceToken)
                print("✅ Push meal reminder sent for \(pet.name)")
            } catch {
                print("❌ Failed to send push meal reminder for \(pet.name): \(error)")
                // Continue - local notification was already sent
            }
        } else {
            print("⚠️ Push notifications not available for meal reminder - local notification sent only")
        }
    }
    
    /**
     * Load settings from UserDefaults
     */
    private func loadSettings() {
        isEnabled = UserDefaults.standard.object(forKey: UserDefaultsKeys.mealRemindersEnabled) as? Bool ?? true
        
        let hour = UserDefaults.standard.object(forKey: UserDefaultsKeys.reminderTimeHour) as? Int ?? 18
        let minute = UserDefaults.standard.object(forKey: UserDefaultsKeys.reminderTimeMinute) as? Int ?? 0
        
        reminderTime = DateComponents(hour: hour, minute: minute)
    }
    
    /**
     * Save settings to UserDefaults
     */
    private func saveSettings() {
        UserDefaults.standard.set(isEnabled, forKey: UserDefaultsKeys.mealRemindersEnabled)
        UserDefaults.standard.set(reminderTime.hour, forKey: UserDefaultsKeys.reminderTimeHour)
        UserDefaults.standard.set(reminderTime.minute, forKey: UserDefaultsKeys.reminderTimeMinute)
        UserDefaults.standard.synchronize()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension MealReminderService: UNUserNotificationCenterDelegate {
    /**
     * Handle notification when app is in foreground
     */
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // If it's the daily check notification, trigger the check
        if notification.request.identifier == NotificationIdentifiers.dailyCheck {
            Task { @MainActor in
                await MealReminderService.shared.checkAndSendMealReminders()
            }
            // Don't show the silent check notification
            completionHandler([])
            return
        }
        
        // Show meal reminder notifications
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .badge, .sound])
        } else {
            completionHandler([.alert, .badge, .sound])
        }
    }
    
    /**
     * Handle notification tap
     */
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        if let action = userInfo["action"] as? String,
           action == "log_meal" {
            // Navigate to meal logging view
            // Post notification to handle navigation
            NotificationCenter.default.post(
                name: .navigateToMealLogging,
                object: nil,
                userInfo: ["pet_id": userInfo["pet_id"] as? String ?? ""]
            )
        }
        
        completionHandler()
    }
}

