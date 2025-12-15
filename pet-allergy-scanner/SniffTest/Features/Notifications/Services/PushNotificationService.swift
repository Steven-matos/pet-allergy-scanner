//
//  PushNotificationService.swift
//  SniffTest
//
//  Created by Steven Matos on 1/10/25.
//

import Foundation
import UserNotifications
import UIKit

/// Service for managing push notifications via Apple Push Notification service (APNs)
/// Handles device token registration, notification scheduling, and APNs communication
/// Follows SOLID principles with single responsibility for push notification management
@MainActor
class PushNotificationService: NSObject, ObservableObject {
    static let shared = PushNotificationService()
    
    // MARK: - Published Properties
    
    /// Device token for push notifications
    @Published var deviceToken: String? {
        didSet {
            if let token = deviceToken {
                UserDefaults.standard.set(token, forKey: "device_token")
                // Register token with server
                Task {
                    await registerDeviceTokenWithServer(token)
                }
            } else {
                UserDefaults.standard.removeObject(forKey: "device_token")
            }
            UserDefaults.standard.synchronize()
        }
    }
    
    /// Push notification authorization status
    @Published var isAuthorized = false
    
    /// Connection status to APNs
    @Published var isConnectedToAPNs = false
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let apiService = APIService.shared
    private let authService = AuthService.shared
    
    // MARK: - Constants
    
    private enum UserDefaultsKeys {
        static let deviceToken = "device_token"
        static let lastTokenRegistration = "last_token_registration"
    }
    
    private enum NotificationTypes {
        static let engagement = "engagement_reminder"
        static let birthday = "birthday_celebration"
        static let weeklyReminder = "weekly_scan_reminder"
        static let monthlyReminder = "monthly_scan_reminder"
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        loadStoredDeviceToken()
        setupNotificationCenter()
    }
    
    // MARK: - Public Methods
    
    /// Request push notification permissions and register for remote notifications
    /// - Returns: Boolean indicating if permission was granted
    func requestPushNotificationPermission() async -> Bool {
        // Track permission prompted
        await MainActor.run {
            PostHogAnalytics.trackPushPermissionPrompted()
        }
        do {
            // Request authorization for push notifications
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound, .provisional]
            )
            
            isAuthorized = granted
            
            // Track permission result
            await MainActor.run {
                PostHogAnalytics.trackPushPermissionResult(status: granted ? "granted" : "denied")
            }
            
            if granted {
                // Register for remote notifications to get device token
                UIApplication.shared.registerForRemoteNotifications()
            }
            
            return granted
        } catch {
            print("❌ Failed to request push notification permission: \(error)")
            return false
        }
    }
    
    /// Register device token with APNs
    /// - Parameter deviceToken: The device token received from APNs
    func registerDeviceToken(_ deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        print("✅ Device token registered: \(tokenString)")
    }
    
    /// Send engagement reminder push notification
    /// - Parameters:
    ///   - type: Type of engagement notification
    ///   - title: Notification title
    ///   - body: Notification body
    ///   - delay: Delay in seconds before sending (default: 0 for immediate)
    func sendEngagementNotification(
        type: EngagementNotificationType,
        title: String,
        body: String,
        delay: TimeInterval = 0
    ) async {
        guard isAuthorized, let deviceToken = deviceToken else {
            print("❌ Cannot send push notification: not authorized or no device token")
            return
        }
        
        let payload = createEngagementNotificationPayload(
            type: type,
            title: title,
            body: body,
            delay: delay
        )
        
        do {
            try await sendPushNotification(payload: payload, deviceToken: deviceToken)
            print("✅ Engagement notification sent: \(type.rawValue)")
        } catch {
            print("❌ Failed to send engagement notification: \(error)")
        }
    }
    
    /// Send birthday celebration push notification
    /// - Parameters:
    ///   - petName: Name of the pet
    ///   - petId: ID of the pet
    ///   - delay: Delay in seconds before sending (default: 0 for immediate)
    func sendBirthdayNotification(
        petName: String,
        petId: String,
        delay: TimeInterval = 0
    ) async {
        guard isAuthorized, let deviceToken = deviceToken else {
            print("❌ Cannot send push notification: not authorized or no device token")
            return
        }
        
        let payload = createBirthdayNotificationPayload(
            petName: petName,
            petId: petId,
            delay: delay
        )
        
        do {
            try await sendPushNotification(payload: payload, deviceToken: deviceToken)
            print("✅ Birthday notification sent for \(petName)")
        } catch {
            print("❌ Failed to send birthday notification: \(error)")
        }
    }
    
    /// Schedule recurring engagement notifications
    func scheduleEngagementNotifications() async {
        guard isAuthorized else { return }
        
        // Schedule weekly reminder (7 days from now)
        await sendEngagementNotification(
            type: .weekly,
            title: "🔍 Time for a Scan!",
            body: "Keep your pet safe by scanning their food ingredients regularly.",
            delay: 7 * 24 * 60 * 60 // 7 days in seconds
        )
        
        // Schedule monthly reminder (30 days from now)
        await sendEngagementNotification(
            type: .monthly,
            title: "🐾 We Miss You!",
            body: "It's been a while since your last scan. Your pet's health is important to us.",
            delay: 30 * 24 * 60 * 60 // 30 days in seconds
        )
    }
    
    /// Cancel all scheduled push notifications
    func cancelAllPushNotifications() async {
        do {
            try await apiService.cancelAllPushNotifications()
            print("✅ All push notifications cancelled")
        } catch {
            print("❌ Failed to cancel push notifications: \(error)")
        }
    }
    
    /// Check if device token needs to be refreshed
    func checkTokenValidity() async {
        guard let lastRegistration = userDefaults.object(forKey: UserDefaultsKeys.lastTokenRegistration) as? Date else {
            // No previous registration, request new token
            _ = await requestPushNotificationPermission()
            return
        }
        
        // Refresh token if it's older than 30 days
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        if lastRegistration < thirtyDaysAgo {
            _ = await requestPushNotificationPermission()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadStoredDeviceToken() {
        deviceToken = userDefaults.string(forKey: UserDefaultsKeys.deviceToken)
    }
    
    private func setupNotificationCenter() {
        // Set this service as the notification center delegate
        // This ensures push notifications are properly displayed in the notification bar
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification authorization if not already granted
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    /// Check current notification authorization status
    private func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
        
        if isAuthorized {
            print("✅ Push notifications authorized - notifications will appear in notification bar")
        } else {
            print("⚠️ Push notifications not authorized - notifications won't appear in notification bar")
        }
    }
    
    /// Register device token with the server
    /// - Parameter token: The device token to register
    private func registerDeviceTokenWithServer(_ token: String) async {
        do {
            try await apiService.registerDeviceToken(token)
            
            // Update last registration date
            userDefaults.set(Date(), forKey: UserDefaultsKeys.lastTokenRegistration)
            userDefaults.synchronize()
            
            print("✅ Device token registered with server")
        } catch {
            print("❌ Failed to register device token with server: \(error)")
        }
    }
    
    /// Create engagement notification payload
    /// - Parameters:
    ///   - type: Type of engagement notification
    ///   - title: Notification title
    ///   - body: Notification body
    ///   - delay: Delay in seconds
    /// - Returns: Push notification payload
    private func createEngagementNotificationPayload(
        type: EngagementNotificationType,
        title: String,
        body: String,
        delay: TimeInterval
    ) -> [String: Any] {
        var payload: [String: Any] = [
            "aps": [
                "alert": [
                    "title": title,
                    "body": body
                ],
                "sound": "default",
                "badge": 1,
                "category": "engagement"
            ],
            "type": type.rawValue,
            "action": "navigate_to_scan"
        ]
        
        if delay > 0 {
            payload["delay"] = delay
        }
        
        return payload
    }
    
    /// Create birthday notification payload
    /// - Parameters:
    ///   - petName: Name of the pet
    ///   - petId: ID of the pet
    ///   - delay: Delay in seconds
    /// - Returns: Push notification payload
    private func createBirthdayNotificationPayload(
        petName: String,
        petId: String,
        delay: TimeInterval
    ) -> [String: Any] {
        var payload: [String: Any] = [
            "aps": [
                "alert": [
                    "title": "🎉 Surprise! It's \(petName)'s Birthday Month! 🎂",
                    "body": "This month is \(petName)'s special time! Time to celebrate! 🐾✨"
                ],
                "sound": "default",
                "badge": 1,
                "category": "birthday"
            ],
            "type": "birthday_celebration",
            "pet_id": petId,
            "action": "show_birthday_celebration"
        ]
        
        if delay > 0 {
            payload["delay"] = delay
        }
        
        return payload
    }
    
    /// Send push notification via server
    /// - Parameters:
    ///   - payload: Notification payload
    ///   - deviceToken: Target device token
    func sendPushNotification(payload: [String: Any], deviceToken: String) async throws {
        try await apiService.sendPushNotification(payload: payload, deviceToken: deviceToken)
    }
}

// MARK: - Engagement Notification Types

enum EngagementNotificationType: String, CaseIterable {
    case weekly = "weekly_reminder"
    case monthly = "monthly_reminder"
    case custom = "custom_engagement"
    
    var displayName: String {
        switch self {
        case .weekly:
            return "Weekly Reminder"
        case .monthly:
            return "Monthly Reminder"
        case .custom:
            return "Custom Engagement"
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

@MainActor
extension PushNotificationService: @MainActor UNUserNotificationCenterDelegate {
    /// Handle notification when app is in foreground
    /// This ensures notifications appear in the notification bar even when app is open
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("📱 Notification will present - showing in notification bar")
        
        // Show notification in notification bar/banner with badge and sound
        // .banner = shows at top of screen as banner notification
        // .list = shows in notification center
        // .badge = updates app badge number
        // .sound = plays notification sound
        if #available(iOS 14.0, *) {
            // iOS 14+: Use .banner to show notification banner at top of screen
            completionHandler([.banner, .list, .badge, .sound])
        } else {
            // iOS 13 and below: Use .alert for notification banner
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
        
        // Clear badge when notification is tapped
        clearBadge()
        
        // Handle engagement notifications
        if let action = userInfo["action"] as? String {
            switch action {
            case "navigate_to_scan":
                NotificationCenter.default.post(name: .navigateToScan, object: nil)
            case "show_birthday_celebration":
                if let petId = userInfo["pet_id"] as? String {
                    NotificationCenter.default.post(
                        name: .showBirthdayCelebration,
                        object: nil,
                        userInfo: ["pet_id": petId]
                    )
                }
            default:
                break
            }
        }
        
        completionHandler()
    }
    
    // MARK: - Badge Management
    
    /**
     * Clear the app badge number
     * Call this when app becomes active or when notifications are read
     * Uses iOS 16+ API (setBadgeCount) for iOS 17.2+ compatibility
     */
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error = error {
                print("⚠️ Failed to clear badge: \(error)")
            } else {
                print("✅ Badge cleared")
            }
        }
    }
}

