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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(notificationManager)
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

        return true
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
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Handle push notification data
        print("📱 Received push notification: \(userInfo)")
        completionHandler(.newData)
    }
}
