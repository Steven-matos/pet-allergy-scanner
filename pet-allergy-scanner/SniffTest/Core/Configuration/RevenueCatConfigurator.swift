//
//  RevenueCatConfigurator.swift
//  SniffTest
//
//  Helper for configuring the RevenueCat SDK and subscription provider.
//

import Foundation
import RevenueCat
import AdSupport
import os.log

/// Coordinates RevenueCat SDK configuration using app configuration values.
enum RevenueCatConfigurator {
    private static let logger = Logger(subsystem: "com.snifftest.app", category: "RevenueCat")
    
    /// Check if RevenueCat SDK is configured and ready to use
    @MainActor
    private static var isConfigured: Bool {
        RevenueCatSubscriptionProvider.shared.isConfigured
    }
    
    /// Configure the RevenueCat SDK and subscription provider using Info.plist values.
    @MainActor
    static func configure() {
        let apiKey = Configuration.revenueCatAPIKey
        let entitlementID = Configuration.revenueCatEntitlementID
        
        logger.info("🔧 Starting RevenueCat configuration...")
        logger.info("API Key present: \(!apiKey.isEmpty), length: \(apiKey.count)")
        logger.info("Entitlement ID: \(entitlementID)")
        logger.info("Build mode: \(Configuration.isDebugMode ? "DEBUG" : "RELEASE")")
        
        let providerConfiguration = RevenueCatConfiguration(apiKey: apiKey, entitlementID: entitlementID)
        
        RevenueCatSubscriptionProvider.shared.configure(with: providerConfiguration)
        
        // Wait a moment for configuration to complete, then check
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            if isConfigured {
                logger.info("✅ RevenueCat SDK configuration verified")
                // Enable device identifier collection for better analytics
                // AdSupport framework is required for attribution data
                Purchases.shared.attribution.collectDeviceIdentifiers()
            } else {
                logger.warning("⚠️ RevenueCat SDK not configured - skipping device identifier collection")
                logger.warning("Check logs above for configuration failure reason")
            }
        }
        
        if apiKey.isEmpty {
            logger.error("RevenueCat API key is empty. Update Info.plist with REVENUECAT_PUBLIC_SDK_KEY before shipping.")
        }
    }
    
    /// Identify the user with RevenueCat when they log in
    /// This links the user's purchases to their account across devices
    /// After identification, syncs subscription status with backend to ensure database is up-to-date
    /// - Parameter userId: The unique user identifier from your backend
    @MainActor
    static func identifyUser(_ userId: String) async {
        // Guard: Only proceed if RevenueCat SDK is configured
        guard isConfigured else {
            logger.debug("RevenueCat SDK not configured - skipping user identification")
            return
        }
        
        // Check if user is already identified to avoid duplicate calls
        let currentAppUserId = Purchases.shared.appUserID
        if currentAppUserId == userId {
            logger.debug("User \(userId) already identified - skipping duplicate identifyUser call")
            return
        }
        
        do {
            let (customerInfo, _) = try await Purchases.shared.logIn(userId)
            
            // Refresh customer info to update subscription provider state
            // This ensures the provider is aware of any purchases transferred from anonymous account
            await RevenueCatSubscriptionProvider.shared.refreshCustomerInfo()
            
            // Check if user has active entitlement
            let entitlementID = Configuration.revenueCatEntitlementID
            let hasActiveEntitlement = customerInfo.entitlements[entitlementID]?.isActive == true
            
            if hasActiveEntitlement {
                
                // Sync subscription status with backend to ensure database is updated
                // This is especially important when anonymous purchases were transferred to the account
                // The refreshCustomerInfo above will also trigger a sync via applyCustomerInfo,
                // but we do an explicit sync here as well to ensure consistency
                await syncSubscriptionWithBackend(userId: userId)
            } else {
                logger.debug("User \(userId) does not have active subscription entitlement")
            }
        } catch {
            logger.error("Failed to identify RevenueCat user: \(error.localizedDescription)")
        }
    }
    
    /// Sync subscription status with backend API
    /// Called after user identification to ensure database reflects current subscription status
    /// - Parameter userId: User ID for syncing
    @MainActor
    private static func syncSubscriptionWithBackend(userId: String) async {
        do {
            // Call backend subscription status endpoint
            // The backend will check database, and if no subscription found, verify with RevenueCat API
            let apiService = APIService.shared
            let response: SubscriptionStatusResponse = try await apiService.get(
                endpoint: "/subscriptions/status",
                responseType: SubscriptionStatusResponse.self
            )
            
            if response.hasSubscription {
            } else {
                logger.debug("No active subscription found in backend for user \(userId)")
            }
        } catch {
            // Log but don't fail - this is a background sync operation
            logger.warning("Failed to sync subscription status with backend: \(error.localizedDescription)")
        }
    }
    
    /// Response model for subscription status endpoint
    /// We only decode the fields we need - subscription details are optional
    private struct SubscriptionStatusResponse: Codable {
        let hasSubscription: Bool
        
        enum CodingKeys: String, CodingKey {
            case hasSubscription = "has_subscription"
            // Ignore subscription and user_role fields - we only need has_subscription
        }
    }
    
    /// Log out the current RevenueCat user (call when user logs out)
    /// This clears the user association but keeps anonymous purchase history
    @MainActor
    static func logoutUser() async {
        // Guard: Only proceed if RevenueCat SDK is configured
        guard isConfigured else {
            logger.debug("RevenueCat SDK not configured - skipping logout")
            return
        }
        
        do {
            _ = try await Purchases.shared.logOut()
        } catch {
            logger.error("Failed to log out RevenueCat user: \(error.localizedDescription)")
        }
    }
}
