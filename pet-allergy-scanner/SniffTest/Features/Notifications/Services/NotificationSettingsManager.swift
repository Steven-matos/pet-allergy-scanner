//
//  NotificationSettingsManager.swift
//  SniffTest
//
//  Created by Steven Matos on 1/10/25.
//

import Foundation
import UserNotifications
import UIKit

/// Centralized notification settings management for the pet allergy scanner app
/// Consolidates all notification-related settings and preferences in one place
/// Follows SOLID principles with single responsibility for notification management
@MainActor
class NotificationSettingsManager: NSObject, ObservableObject {
    static let shared = NotificationSettingsManager()
    
    // MARK: - Published Properties for UI Binding
    
    /// Overall notification authorization status
    @Published var isAuthorized = false
    
    /// Master toggle for all notifications (from SettingsManager)
    @Published var enableNotifications: Bool {
        didSet {
            UserDefaults.standard.set(enableNotifications, forKey: "enableNotifications")
            UserDefaults.standard.synchronize()
            
            // If notifications are disabled, cancel all notifications
            if !enableNotifications {
                cancelAllNotifications()
            } else {
                // If notifications are enabled, check authorization and schedule if needed
                Task {
                    await checkAuthorizationStatus()
                    if isAuthorized {
                        scheduleAllNotifications()
                    }
                }
            }
        }
    }
    
    /// Birthday easter egg - always enabled but only shows once per year during birth month
    /// This is a surprise feature that doesn't have a user toggle
    private var birthdayEasterEggEnabled: Bool {
        return enableNotifications && isAuthorized
    }
    
    /// Track which pets have already shown birthday celebration this year
    @Published private var birthdayCelebrationsShownThisYear: Set<String> = [] {
        didSet {
            UserDefaults.standard.set(Array(birthdayCelebrationsShownThisYear), forKey: "birthday_celebrations_shown_this_year")
            UserDefaults.standard.synchronize()
        }
    }
    
    /// Engagement notification toggle
    @Published var engagementNotificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(engagementNotificationsEnabled, forKey: "engagement_notifications_enabled")
            UserDefaults.standard.synchronize()
            
            // Update engagement notifications immediately
            if engagementNotificationsEnabled && isAuthorized && enableNotifications {
                scheduleEngagementNotifications()
            } else {
                cancelEngagementNotifications()
            }
        }
    }
    
    /// Last scan date for engagement tracking
    @Published var lastScanDate: Date? {
        didSet {
            if let date = lastScanDate {
                UserDefaults.standard.set(date, forKey: "last_scan_date")
            } else {
                UserDefaults.standard.removeObject(forKey: "last_scan_date")
            }
            UserDefaults.standard.synchronize()
        }
    }
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let petService = CachedPetService.shared
    private let scanService = ScanService.shared
    private let pushNotificationService = PushNotificationService.shared
    
    // MARK: - Constants
    
    private enum NotificationIdentifiers {
        static let birthdayPrefix = "pet_birthday_"
        static let engagementPrefix = "engagement_reminder_"
        static let weeklyReminder = "weekly_scan_reminder"
        static let monthlyReminder = "monthly_scan_reminder"
    }
    
    private enum UserDefaultsKeys {
        static let enableNotifications = "enableNotifications"
        static let engagementNotificationsEnabled = "engagement_notifications_enabled"
        static let lastScanDate = "last_scan_date"
        static let lastEngagementNotificationDate = "last_engagement_notification_date"
        static let birthdayCelebrationsShownThisYear = "birthday_celebrations_shown_this_year"
    }
    
    // MARK: - Initialization
    
    override init() {
        // Load settings from UserDefaults with sensible defaults
        self.enableNotifications = UserDefaults.standard.object(forKey: UserDefaultsKeys.enableNotifications) as? Bool ?? true
        self.engagementNotificationsEnabled = UserDefaults.standard.object(forKey: UserDefaultsKeys.engagementNotificationsEnabled) as? Bool ?? true
        self.lastScanDate = UserDefaults.standard.object(forKey: UserDefaultsKeys.lastScanDate) as? Date
        
        // Load birthday celebrations shown this year
        if let celebrationsArray = UserDefaults.standard.array(forKey: UserDefaultsKeys.birthdayCelebrationsShownThisYear) as? [String] {
            self.birthdayCelebrationsShownThisYear = Set(celebrationsArray)
        } else {
            self.birthdayCelebrationsShownThisYear = []
        }
        
        super.init()
        
        setupNotificationCenter()
        Task {
            await checkAuthorizationStatus()
        }
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
            
            // Also request push notification permissions
            if granted {
                let pushGranted = await pushNotificationService.requestPushNotificationPermission()
                if pushGranted {
                    print("✅ Push notifications authorized")
                }
            }
            
            // If permission granted and notifications enabled, schedule all notifications
            if granted && enableNotifications {
                scheduleAllNotifications()
            }
            
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
    
    /// Schedule all notifications based on current settings
    func scheduleAllNotifications() {
        guard isAuthorized && enableNotifications else { return }
        
        scheduleBirthdayNotifications()
        scheduleEngagementNotifications()
    }
    
    /// Schedule birthday easter egg notifications for all pets
    /// Only shows once per year during the pet's birth month as a surprise
    func scheduleBirthdayNotifications() {
        guard birthdayEasterEggEnabled else { return }
        
        // Cancel existing birthday notifications
        cancelBirthdayNotifications()
        
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())
        
        for pet in petService.pets {
            guard let birthday = pet.birthday else { continue }
            
            let petBirthMonth = Calendar.current.component(.month, from: birthday)
            
            // Only schedule if it's the pet's birth month and we haven't shown it this year
            let celebrationKey = "\(pet.id)_\(currentYear)"
            if petBirthMonth == currentMonth && !birthdayCelebrationsShownThisYear.contains(celebrationKey) {
                scheduleBirthdayEasterEgg(for: pet, birthday: birthday)
                
                // Also send push notification for birthday celebration
                Task {
                    await pushNotificationService.sendBirthdayNotification(
                        petName: pet.name,
                        petId: pet.id
                    )
                }
            }
        }
    }
    
    /// Schedule engagement reminder notifications
    func scheduleEngagementNotifications() {
        guard isAuthorized && enableNotifications && engagementNotificationsEnabled else { return }
        
        // Cancel existing engagement notifications
        cancelEngagementNotifications()
        
        // Schedule local notifications
        scheduleWeeklyReminder()
        scheduleMonthlyReminder()
        
        // Schedule push notifications for better reliability
        Task {
            await pushNotificationService.scheduleEngagementNotifications()
        }
    }
    
    /// Update last scan date and check for engagement notifications
    func updateLastScanDate() {
        lastScanDate = Date()
        
        // Cancel any pending engagement notifications since user is active
        cancelEngagementNotifications()
        
        // Reschedule engagement notifications for future
        Task {
            await pushNotificationService.scheduleEngagementNotifications()
        }
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
    
    /// Birthday notifications are now an easter egg - no toggle needed
    
    /// Toggle engagement notifications setting (optimized to prevent UI freezing)
    func toggleEngagementNotifications() {
        // Use a background queue to prevent UI blocking
        Task { @MainActor in
            engagementNotificationsEnabled.toggle()
        }
    }
    
    /// Toggle master notifications setting (optimized to prevent UI freezing)
    func toggleMasterNotifications() {
        // Use a background queue to prevent UI blocking
        Task { @MainActor in
            enableNotifications.toggle()
        }
    }
    
    /// Cancel all notifications
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Also cancel push notifications
        Task {
            await pushNotificationService.cancelAllPushNotifications()
        }
    }
    
    /// Reset all notification settings to defaults
    func resetToDefaults() {
        enableNotifications = true
        engagementNotificationsEnabled = true
        lastScanDate = nil
        birthdayCelebrationsShownThisYear.removeAll()
        
        // Force synchronization
        UserDefaults.standard.synchronize()
        
        // Cancel all notifications and reschedule if authorized
        cancelAllNotifications()
        Task {
            await checkAuthorizationStatus()
            if isAuthorized {
                scheduleAllNotifications()
            }
        }
    }
    
    /// Mark a birthday celebration as shown for this year
    /// This prevents the easter egg from showing multiple times per year
    func markBirthdayCelebrationShown(for petId: String) {
        let currentYear = Calendar.current.component(.year, from: Date())
        let celebrationKey = "\(petId)_\(currentYear)"
        birthdayCelebrationsShownThisYear.insert(celebrationKey)
    }
    
    /// Check if a birthday celebration has been shown this year
    func hasBirthdayCelebrationBeenShown(for petId: String) -> Bool {
        let currentYear = Calendar.current.component(.year, from: Date())
        let celebrationKey = "\(petId)_\(currentYear)"
        return birthdayCelebrationsShownThisYear.contains(celebrationKey)
    }
    
    /// Get a summary of all current notification settings for debugging
    func getSettingsSummary() -> [String: Any] {
        return [
            "isAuthorized": isAuthorized,
            "enableNotifications": enableNotifications,
            "birthdayEasterEggEnabled": birthdayEasterEggEnabled,
            "engagementNotificationsEnabled": engagementNotificationsEnabled,
            "lastScanDate": lastScanDate?.description ?? "nil",
            "birthdayCelebrationsShownThisYear": Array(birthdayCelebrationsShownThisYear)
        ]
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationCenter() {
        // NOTE: Do NOT set delegate here - PushNotificationService is the primary delegate
        // set in AppDelegate. This prevents delegate conflicts.
        // PushNotificationService will handle all notification presentation in notification bar
    }
    
    /// Schedule birthday easter egg notification for a specific pet
    /// This is a surprise notification that only shows once per year during the pet's birth month
    private func scheduleBirthdayEasterEgg(for pet: Pet, birthday: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        // Schedule for a random day in the current month (since we only track month, not day)
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        
        // Pick a random day in the month for the surprise
        let randomDay = Int.random(in: 1...daysInMonth)
        
        var triggerDate = DateComponents()
        triggerDate.year = currentYear
        triggerDate.month = currentMonth
        triggerDate.day = randomDay
        triggerDate.hour = 10 // 10 AM
        triggerDate.minute = 0
        
        let content = UNMutableNotificationContent()
        content.title = "🎉 Surprise! It's \(pet.name)'s Birthday Month! 🎂"
        content.body = "This month is \(pet.name)'s special time! Time to celebrate! 🐾✨"
        content.sound = .default
        content.badge = 1
        
        // Add pet image if available
        if let imageUrl = pet.imageUrl, !imageUrl.isEmpty {
            content.userInfo = ["pet_image_url": imageUrl, "pet_id": pet.id]
        }
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "\(NotificationIdentifiers.birthdayPrefix)easter_egg_\(pet.id)",
            content: content,
            trigger: trigger
        )
        
        let finalTriggerDate = triggerDate
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule birthday easter egg for \(pet.name): \(error)")
            } else {
                print("✅ Scheduled birthday easter egg for \(pet.name) on \(finalTriggerDate)")
            }
        }
    }
    
    /// Legacy method - now redirects to easter egg logic
    private func scheduleBirthdayNotification(for pet: Pet, birthday: Date) {
        scheduleBirthdayEasterEgg(for: pet, birthday: birthday)
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

extension NotificationSettingsManager: @MainActor UNUserNotificationCenterDelegate {
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
                // Mark birthday celebration as shown for this year
                markBirthdayCelebrationShown(for: petId)
                
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

extension Notification.Name {
    static let showBirthdayCelebration = Notification.Name("showBirthdayCelebration")
    static let navigateToScan = Notification.Name("navigateToScan")
    static let navigateToMealLogging = Notification.Name("navigateToMealLogging")
    static let navigateToMedication = Notification.Name("navigateToMedication")
    static let userDidLogin = Notification.Name("userDidLogin")
    static let userDidLogout = Notification.Name("userDidLogout")
}
