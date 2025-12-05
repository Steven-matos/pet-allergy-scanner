//
//  SniffTestApp.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI
import UserNotifications

@main
struct SniffTestApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // MEMORY OPTIMIZATION: Create shared service instances once
    private let authService = AuthService.shared
    private let petService = CachedPetService.shared
    private let notificationManager = NotificationManager.shared
    private let cacheCoordinator = UnifiedCacheCoordinator.shared
    
    init() {
        // Initialize cache coordinator on app launch
        // This sets up URLSession caching and lifecycle observers
        _ = cacheCoordinator
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(notificationManager)
                .onOpenURL { url in
                    // Handle deep links from email confirmation and password reset
                    _ = URLHandler.shared.handleURL(url)
                }
                .task {
                    // Cache coordinator is initialized automatically
                    // Background sync is handled by CacheServerSyncService
                }
        }
    }
}

/// App delegate to handle push notification registration and system configuration
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Set up push notification delegate
        UNUserNotificationCenter.current().delegate = PushNotificationService.shared
        
        // Configure system warning suppression to reduce console noise
        SystemWarningSuppressionHelper.shared.configure()
        
        // Configure RevenueCat subscriptions using Info.plist values
        RevenueCatConfigurator.configure()
        
        // Configure PostHog analytics using Info.plist values
        PostHogConfigurator.configure()
        
        // Clear badge on app launch
        PushNotificationService.shared.clearBadge()

        return true
    }
    
    /// Handle app becoming active (foreground)
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Clear badge when app becomes active
        PushNotificationService.shared.clearBadge()
    }
    
    /// Handle URL opening (fallback for deep links)
    /// This is called when the app is opened via a URL scheme or universal link
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        print("AppDelegate: Received URL - \(url)")
        // Handle the URL through the shared URL handler
        return URLHandler.shared.handleURL(url)
    }
    
    /// Handle successful device token registration
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationService.shared.registerDeviceToken(deviceToken)
    }
    
    /// Handle device token registration failure
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
    
    /// Handle push notification received while app is running
    /// This method is called when a remote notification arrives
    /// iOS will automatically display it in the notification bar if:
    /// 1. App is in background/terminated - automatically shown
    /// 2. App is in foreground - shown via UNUserNotificationCenterDelegate
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("📱 Received push notification: \(userInfo)")
        
        // Extract notification content from userInfo
        if let aps = userInfo["aps"] as? [String: Any],
           let alert = aps["alert"] as? [String: Any] {
            
            // Create a local notification to ensure it appears in notification bar
            // This is especially important if the remote notification doesn't trigger properly
            let content = UNMutableNotificationContent()
            content.title = alert["title"] as? String ?? "Notification"
            content.body = alert["body"] as? String ?? ""
            content.sound = .default
            content.badge = aps["badge"] as? NSNumber
            content.userInfo = userInfo
            
            // Add category for actions if present
            if let category = aps["category"] as? String {
                content.categoryIdentifier = category
            }
            
            // Schedule immediate notification to appear in notification bar
            let request = UNNotificationRequest(
                identifier: "remote_\(UUID().uuidString)",
                content: content,
                trigger: nil // nil trigger = immediate delivery
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Failed to present notification in notification bar: \(error)")
                } else {
                    print("✅ Notification scheduled to appear in notification bar")
                }
            }
        }
        
        completionHandler(.newData)
    }
}
