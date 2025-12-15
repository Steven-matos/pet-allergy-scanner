//
//  AnalyticsPrivacyManager.swift
//  SniffTest
//
//  Manages analytics privacy controls including user consent and internal user filtering
//  Integrates with existing AnalyticsManager consent system
//

import Foundation
import os.log

/// Manages analytics privacy controls and consent
/// Handles opt-out, internal user filtering, and operational event tracking
@MainActor
class AnalyticsPrivacyManager {
    static let shared = AnalyticsPrivacyManager()
    
    private let logger = Logger(subsystem: "com.snifftest.app", category: "AnalyticsPrivacy")
    
    // MARK: - UserDefaults Keys
    
    private enum UserDefaultsKeys {
        static let analyticsConsent = "analytics_consent"
        static let analyticsEnabled = "analytics_enabled"
    }
    
    // MARK: - Internal User Detection
    
    /// Email domains that indicate internal/test users
    private let internalEmailDomains = [
        "@snifftest.com",
        "@test.com",
        "@example.com"
    ]
    
    /// Check if analytics is enabled (respects user consent)
    var isAnalyticsEnabled: Bool {
        // Check explicit consent setting
        if let consent = UserDefaults.standard.object(forKey: UserDefaultsKeys.analyticsConsent) as? Bool {
            return consent
        }
        
        // Check enabled setting (for backwards compatibility)
        if let enabled = UserDefaults.standard.object(forKey: UserDefaultsKeys.analyticsEnabled) as? Bool {
            return enabled
        }
        
        // Default to enabled (user can opt out in settings)
        return true
    }
    
    /// Set analytics consent
    /// - Parameter enabled: Whether user consents to analytics
    func setAnalyticsEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: UserDefaultsKeys.analyticsConsent)
        UserDefaults.standard.set(enabled, forKey: UserDefaultsKeys.analyticsEnabled)
        UserDefaults.standard.synchronize()
        
        logger.info("Analytics consent updated: \(enabled)")
        
        // If disabled, reset PostHog user identification
        if !enabled {
            PostHogAnalytics.resetUser()
        }
    }
    
    /// Check if current user is an internal/test user
    /// - Parameter email: User's email address
    /// - Returns: True if user is internal
    func isInternalUser(email: String?) -> Bool {
        guard let email = email?.lowercased() else { return false }
        
        // Check if email matches internal domains
        for domain in internalEmailDomains {
            if email.contains(domain) {
                return true
            }
        }
        
        // Check for common test email patterns
        if email.contains("test@") || email.contains("admin@") || email.contains("dev@") {
            return true
        }
        
        return false
    }
    
    /// Get internal user property for filtering
    /// - Parameter email: User's email address
    /// - Returns: Dictionary with is_internal property if user is internal
    func getInternalUserProperty(email: String?) -> [String: Any] {
        if isInternalUser(email: email) {
            return ["is_internal": true]
        }
        return [:]
    }
    
    /// Check if an event should be tracked
    /// Some operational events may be tracked even when analytics is disabled
    /// - Parameter eventName: Name of the event
    /// - Parameter isOperational: Whether this is an operational event (always tracked)
    /// - Returns: True if event should be tracked
    func shouldTrackEvent(_ eventName: String, isOperational: Bool = false) -> Bool {
        // Operational events are always tracked (e.g., crashes, critical errors)
        if isOperational {
            return true
        }
        
        // Regular events respect user consent
        return isAnalyticsEnabled
    }
    
    /// Initialize privacy manager
    /// Checks existing consent settings and syncs with AnalyticsManager
    func initialize() {
        // Sync with existing AnalyticsManager consent
        let existingConsent = UserDefaults.standard.object(forKey: UserDefaultsKeys.analyticsConsent) as? Bool
        let existingEnabled = UserDefaults.standard.object(forKey: UserDefaultsKeys.analyticsEnabled) as? Bool
        
        // If AnalyticsManager has a setting, use it
        if let enabled = existingEnabled {
            UserDefaults.standard.set(enabled, forKey: UserDefaultsKeys.analyticsConsent)
        } else if existingConsent == nil {
            // Default to enabled if no setting exists
            UserDefaults.standard.set(true, forKey: UserDefaultsKeys.analyticsConsent)
        }
        
        UserDefaults.standard.synchronize()
        
        logger.info("Analytics privacy manager initialized. Enabled: \(self.isAnalyticsEnabled)")
    }
}
