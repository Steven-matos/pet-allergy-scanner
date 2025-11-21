//
//  RevenueCatConfigurator.swift
//  SniffTest
//
//  Helper for configuring the RevenueCat SDK and subscription provider.
//

import Foundation
import RevenueCat
import os.log

/// Coordinates RevenueCat SDK configuration using app configuration values.
enum RevenueCatConfigurator {
    private static let logger = Logger(subsystem: "com.snifftest.app", category: "RevenueCat")
    
    /// Configure the RevenueCat SDK and subscription provider using Info.plist values.
    @MainActor
    static func configure() {
        let apiKey = Configuration.revenueCatAPIKey
        let entitlementID = Configuration.revenueCatEntitlementID
        let providerConfiguration = RevenueCatConfiguration(apiKey: apiKey, entitlementID: entitlementID)
        
        RevenueCatSubscriptionProvider.shared.configure(with: providerConfiguration)
        
        // Enable device identifier collection for better analytics
        Purchases.shared.attribution.collectDeviceIdentifiers()
        
        if apiKey.isEmpty {
            logger.error("RevenueCat API key is empty. Update Info.plist with REVENUECAT_PUBLIC_SDK_KEY before shipping.")
        } else {
            logger.info("RevenueCat configured with entitlement: \(entitlementID)")
        }
    }
    
    /// Identify the user with RevenueCat when they log in
    /// This links the user's purchases to their account across devices
    /// - Parameter userId: The unique user identifier from your backend
    @MainActor
    static func identifyUser(_ userId: String) async {
        // Check if user is already identified to avoid duplicate calls
        let currentAppUserId = Purchases.shared.appUserID
        if currentAppUserId == userId {
            logger.debug("User \(userId) already identified - skipping duplicate identifyUser call")
            return
        }
        
        do {
            let (customerInfo, _) = try await Purchases.shared.logIn(userId)
            logger.info("RevenueCat user identified: \(userId)")
            
            // Check if user has active entitlement
            let entitlementID = Configuration.revenueCatEntitlementID
            if customerInfo.entitlements[entitlementID]?.isActive == true {
                logger.info("User has active subscription entitlement: \(entitlementID)")
            }
        } catch {
            logger.error("Failed to identify RevenueCat user: \(error.localizedDescription)")
        }
    }
    
    /// Log out the current RevenueCat user (call when user logs out)
    /// This clears the user association but keeps anonymous purchase history
    @MainActor
    static func logoutUser() async {
        do {
            _ = try await Purchases.shared.logOut()
            logger.info("RevenueCat user logged out")
        } catch {
            logger.error("Failed to log out RevenueCat user: \(error.localizedDescription)")
        }
    }
}
