//
//  NotificationManager.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import SwiftUI
import Combine

/// Notification manager that coordinates notification system with app lifecycle
/// Handles birthday celebrations, engagement reminders, and notification scheduling
@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var showBirthdayCelebration = false
    @Published var birthdayPet: Pet?
    @Published var navigateToScan = false
    
    private let notificationSettingsManager = NotificationSettingsManager.shared
    private let mealReminderService = MealReminderService.shared
    private let petService = CachedPetService.shared
    private let scanService = ScanService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNotificationObservers()
        setupServiceObservers()
    }
    
    // MARK: - Public Methods
    
    /// Initialize notification system when app starts
    func initializeNotifications() {
        Task {
            await notificationSettingsManager.checkAuthorizationStatus()
            notificationSettingsManager.scheduleAllNotifications()
            checkForBirthdayCelebrations()
            
            // Initialize meal reminder service
            mealReminderService.scheduleDailyCheck()
        }
    }
    
    /// Handle app becoming active (foreground)
    func handleAppBecameActive() {
        // Clear badge when app becomes active
        PushNotificationService.shared.clearBadge()
        
        Task {
            await notificationSettingsManager.checkAuthorizationStatus()
            checkForBirthdayCelebrations()
            checkEngagementStatus()
            
            // Check and sync subscription status to ensure user role is up-to-date
            // This handles cases where backend has premium role but app cache is stale
            await RevenueCatSubscriptionProvider.shared.checkAndSyncSubscriptionStatus()
        }
    }
    
    /// Handle scan completion
    func handleScanCompleted() {
        notificationSettingsManager.updateLastScanDate()
    }
    
    /// Schedule all notifications based on current data
    func scheduleAllNotifications() {
        notificationSettingsManager.scheduleAllNotifications()
    }
    
    /// Check if any pets have birthdays today and show celebration
    func checkForBirthdayCelebrations() {
        let petsWithBirthday = notificationSettingsManager.getPetsWithBirthdayToday()
        
        if let firstPet = petsWithBirthday.first {
            birthdayPet = firstPet
            showBirthdayCelebration = true
            
            // Schedule haptic feedback
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedback.impactOccurred()
            }
        }
    }
    
    /// Check engagement status and show reminder if needed
    func checkEngagementStatus() {
        if notificationSettingsManager.shouldShowEngagementReminder() {
            showEngagementReminder()
        }
    }
    
    /// Dismiss birthday celebration
    func dismissBirthdayCelebration() {
        showBirthdayCelebration = false
        birthdayPet = nil
    }
    
    /// Handle navigation to scan view
    func handleNavigateToScan() {
        print("🔍 NotificationManager: handleNavigateToScan() called - setting navigateToScan = true")
        navigateToScan = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("🔍 NotificationManager: Resetting navigateToScan = false")
            self.navigateToScan = false
        }
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationObservers() {
        // Listen for birthday celebration requests
        NotificationCenter.default.publisher(for: .showBirthdayCelebration)
            .sink { [weak self] notification in
                if let petId = notification.userInfo?["pet_id"] as? String,
                   let pet = self?.petService.getPet(id: petId) {
                    self?.birthdayPet = pet
                    self?.showBirthdayCelebration = true
                }
            }
            .store(in: &cancellables)
        
        // Listen for scan navigation requests
        NotificationCenter.default.publisher(for: .navigateToScan)
            .sink { [weak self] notification in
                print("🔍 NotificationManager: Received .navigateToScan notification")
                self?.handleNavigateToScan()
            }
            .store(in: &cancellables)
    }
    
    private func setupServiceObservers() {
        // With @Observable services, we don't need Combine publishers
        // The services will automatically notify SwiftUI views when properties change
        // For notification scheduling, we'll use direct method calls instead
        
        // Schedule birthday notifications when pets are loaded
        Task { @MainActor in
            notificationSettingsManager.scheduleBirthdayNotifications()
        }
    }
    
    private func showEngagementReminder() {
        // Mark reminder as shown today to prevent multiple popups
        notificationSettingsManager.markEngagementReminderShown()
        
        // Create a gentle engagement reminder alert
        let alert = UIAlertController(
            title: "🐾 We Miss You!",
            message: "It's been a while since your last scan. Your pet's health is important to us. Would you like to scan some pet food?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Scan Now", style: .default) { _ in
            self.handleNavigateToScan()
        })
        
        alert.addAction(UIAlertAction(title: "Maybe Later", style: .cancel))
        
        // Present the alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
}

// MARK: - Notification Extension

extension NotificationManager {
    /// Check for daily birthday celebrations (called by app delegate or scene delegate)
    func checkDailyBirthdays() {
        let calendar = Calendar.current
        let now = Date()
        
        // Check if we've already checked today
        let lastCheckKey = "last_birthday_check_date"
        let lastCheckDate = UserDefaults.standard.object(forKey: lastCheckKey) as? Date
        
        if let lastCheck = lastCheckDate,
           calendar.isDate(lastCheck, inSameDayAs: now) {
            return // Already checked today
        }
        
        // Update last check date
        UserDefaults.standard.set(now, forKey: lastCheckKey)
        
        // Check for birthdays
        checkForBirthdayCelebrations()
    }
    
    /// Schedule daily birthday check
    func scheduleDailyBirthdayCheck() {
        let calendar = Calendar.current
        let now = Date()
        
        // Schedule for tomorrow at 9 AM
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let triggerDate = calendar.dateComponents([.year, .month, .day, .hour], from: tomorrow)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: true)
        
        let content = UNMutableNotificationContent()
        content.title = "Daily Check"
        content.body = "Checking for pet birthdays..."
        content.sound = nil
        content.badge = nil
        
        let request = UNNotificationRequest(
            identifier: "daily_birthday_check",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule daily birthday check: \(error)")
            } else {
                print("✅ Scheduled daily birthday check")
            }
        }
    }
}
