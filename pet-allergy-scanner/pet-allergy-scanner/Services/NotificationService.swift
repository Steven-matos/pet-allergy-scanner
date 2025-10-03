//
//  NotificationService.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import UserNotifications
import UIKit

/// Notification service for managing local and push notifications
/// Handles birthday reminders, engagement notifications, and user preferences
@MainActor
class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var isAuthorized = false
    @Published var birthdayNotificationsEnabled = true
    @Published var engagementNotificationsEnabled = true
    @Published var lastScanDate: Date?
    
    private let userDefaults = UserDefaults.standard
    private let petService = PetService.shared
    private let scanService = ScanService.shared
    
    // MARK: - Constants
    private enum NotificationIdentifiers {
        static let birthdayPrefix = "pet_birthday_"
        static let engagementPrefix = "engagement_reminder_"
        static let weeklyReminder = "weekly_scan_reminder"
        static let monthlyReminder = "monthly_scan_reminder"
    }
    
    private enum UserDefaultsKeys {
        static let birthdayNotificationsEnabled = "birthday_notifications_enabled"
        static let engagementNotificationsEnabled = "engagement_notifications_enabled"
        static let lastScanDate = "last_scan_date"
        static let lastEngagementNotificationDate = "last_engagement_notification_date"
    }
    
    override init() {
        super.init()
        loadSettings()
        setupNotificationCenter()
    }
    
    // MARK: - Public Methods
    
    /// Request notification permissions from the user
    /// - Returns: Boolean indicating if permission was granted
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound, .provisional]
            )
            isAuthorized = granted
            return granted
        } catch {
            print("❌ Failed to request notification permission: \(error)")
            return false
        }
    }
    
    /// Check current notification authorization status
    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }
    
    /// Schedule birthday notifications for all pets
    func scheduleBirthdayNotifications() {
        guard isAuthorized && birthdayNotificationsEnabled else { return }
        
        // Cancel existing birthday notifications
        cancelBirthdayNotifications()
        
        for pet in petService.pets {
            guard let birthday = pet.birthday else { continue }
            scheduleBirthdayNotification(for: pet, birthday: birthday)
        }
    }
    
    /// Schedule engagement reminder notifications
    func scheduleEngagementNotifications() {
        guard isAuthorized && engagementNotificationsEnabled else { return }
        
        // Cancel existing engagement notifications
        cancelEngagementNotifications()
        
        // Schedule weekly reminder (7 days)
        scheduleWeeklyReminder()
        
        // Schedule monthly reminder (30 days)
        scheduleMonthlyReminder()
    }
    
    /// Update last scan date and check for engagement notifications
    func updateLastScanDate() {
        lastScanDate = Date()
        userDefaults.set(lastScanDate, forKey: UserDefaultsKeys.lastScanDate)
        
        // Cancel any pending engagement notifications since user is active
        cancelEngagementNotifications()
    }
    
    /// Check if it's any pet's birthday today
    /// - Returns: Array of pets with birthdays today
    func getPetsWithBirthdayToday() -> [Pet] {
        let today = Date()
        let calendar = Calendar.current
        
        return petService.pets.filter { pet in
            guard let birthday = pet.birthday else { return false }
            return calendar.isDate(birthday, inSameDayAs: today)
        }
    }
    
    /// Check if user needs engagement reminder
    /// - Returns: Boolean indicating if engagement reminder should be shown
    func shouldShowEngagementReminder() -> Bool {
        guard let lastScan = lastScanDate else { return true }
        
        let daysSinceLastScan = Calendar.current.dateComponents([.day], from: lastScan, to: Date()).day ?? 0
        return daysSinceLastScan >= 14 // 2 weeks
    }
    
    /// Toggle birthday notifications setting
    func toggleBirthdayNotifications() {
        birthdayNotificationsEnabled.toggle()
        userDefaults.set(birthdayNotificationsEnabled, forKey: UserDefaultsKeys.birthdayNotificationsEnabled)
        
        if birthdayNotificationsEnabled {
            scheduleBirthdayNotifications()
        } else {
            cancelBirthdayNotifications()
        }
    }
    
    /// Toggle engagement notifications setting
    func toggleEngagementNotifications() {
        engagementNotificationsEnabled.toggle()
        userDefaults.set(engagementNotificationsEnabled, forKey: UserDefaultsKeys.engagementNotificationsEnabled)
        
        if engagementNotificationsEnabled {
            scheduleEngagementNotifications()
        } else {
            cancelEngagementNotifications()
        }
    }
    
    /// Cancel all notifications
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationCenter() {
        UNUserNotificationCenter.current().delegate = self
    }
    
    private func loadSettings() {
        birthdayNotificationsEnabled = userDefaults.bool(forKey: UserDefaultsKeys.birthdayNotificationsEnabled)
        engagementNotificationsEnabled = userDefaults.bool(forKey: UserDefaultsKeys.engagementNotificationsEnabled)
        lastScanDate = userDefaults.object(forKey: UserDefaultsKeys.lastScanDate) as? Date
    }
    
    private func scheduleBirthdayNotification(for pet: Pet, birthday: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate next birthday
        var nextBirthday = calendar.nextDate(
            after: now,
            matching: calendar.dateComponents([.month, .day], from: birthday),
            matchingPolicy: .nextTime
        ) ?? birthday
        
        // If next birthday is today, schedule for next year
        if calendar.isDate(nextBirthday, inSameDayAs: now) {
            nextBirthday = calendar.date(byAdding: .year, value: 1, to: nextBirthday) ?? nextBirthday
        }
        
        let content = UNMutableNotificationContent()
        content.title = "🎉 Happy Birthday, \(pet.name)!"
        content.body = "Today is \(pet.name)'s special day! 🐾"
        content.sound = .default
        content.badge = 1
        
        // Add pet image if available
        if let imageUrl = pet.imageUrl, !imageUrl.isEmpty {
            content.userInfo = ["pet_image_url": imageUrl, "pet_id": pet.id]
        }
        
        let triggerDate = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextBirthday)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "\(NotificationIdentifiers.birthdayPrefix)\(pet.id)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule birthday notification for \(pet.name): \(error)")
            } else {
                print("✅ Scheduled birthday notification for \(pet.name) on \(nextBirthday)")
            }
        }
    }
    
    private func scheduleWeeklyReminder() {
        let content = UNMutableNotificationContent()
        content.title = "🔍 Time for a Scan!"
        content.body = "Keep your pet safe by scanning their food ingredients regularly."
        content.sound = .default
        content.badge = 1
        
        // Schedule for 7 days from now at 10 AM
        let triggerDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        let components = Calendar.current.dateComponents([.year, .month, .day], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(year: components.year, month: components.month, day: components.day, hour: 10),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: NotificationIdentifiers.weeklyReminder,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule weekly reminder: \(error)")
            } else {
                print("✅ Scheduled weekly reminder")
            }
        }
    }
    
    private func scheduleMonthlyReminder() {
        let content = UNMutableNotificationContent()
        content.title = "🐾 We Miss You!"
        content.body = "It's been a while since your last scan. Your pet's health is important to us."
        content.sound = .default
        content.badge = 1
        
        // Schedule for 30 days from now at 2 PM
        let triggerDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        let components = Calendar.current.dateComponents([.year, .month, .day], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(year: components.year, month: components.month, day: components.day, hour: 14),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: NotificationIdentifiers.monthlyReminder,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule monthly reminder: \(error)")
            } else {
                print("✅ Scheduled monthly reminder")
            }
        }
    }
    
    private func cancelBirthdayNotifications() {
        let identifiers = petService.pets.map { "\(NotificationIdentifiers.birthdayPrefix)\($0.id)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    private func cancelEngagementNotifications() {
        let identifiers = [
            NotificationIdentifiers.weeklyReminder,
            NotificationIdentifiers.monthlyReminder
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: @MainActor UNUserNotificationCenterDelegate {
    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .badge, .sound])
        } else {
            completionHandler([.alert, .badge, .sound])
        }
    }
    
    /// Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // Handle birthday notification
        if response.notification.request.identifier.hasPrefix(NotificationIdentifiers.birthdayPrefix) {
            if let petId = userInfo["pet_id"] as? String {
                // Navigate to pet profile or show birthday celebration
                Task { @MainActor in
                    handleBirthdayNotificationTap(petId: petId)
                }
            }
        }
        
        // Handle engagement notification
        if response.notification.request.identifier.hasPrefix(NotificationIdentifiers.engagementPrefix) ||
           response.notification.request.identifier == NotificationIdentifiers.weeklyReminder ||
           response.notification.request.identifier == NotificationIdentifiers.monthlyReminder {
            // Navigate to scan view
            Task { @MainActor in
                handleEngagementNotificationTap()
            }
        }
        
        completionHandler()
    }
    
    @MainActor
    private func handleBirthdayNotificationTap(petId: String) {
        // Post notification to show birthday celebration
        NotificationCenter.default.post(
            name: .showBirthdayCelebration,
            object: nil,
            userInfo: ["pet_id": petId]
        )
    }
    
    @MainActor
    private func handleEngagementNotificationTap() {
        // Post notification to navigate to scan view
        NotificationCenter.default.post(
            name: .navigateToScan,
            object: nil
        )
    }
}

// MARK: - Notification Names
// Note: Notification names are now defined in NotificationSettingsManager.swift
