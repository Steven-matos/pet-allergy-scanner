//
//  AnalyticsManager.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import Foundation
import SwiftUI
import os.log

/// Analytics manager for tracking app usage and errors
@MainActor
class AnalyticsManager: ObservableObject {
    static let shared = AnalyticsManager()
    
    private let logger = Logger(subsystem: "com.petallergyscanner.app", category: "analytics")
    @Published private var isEnabled: Bool = true
    
    private init() {
        // Check user consent for analytics
        checkAnalyticsConsent()
    }
    
    /// Track a custom event
    /// - Parameters:
    ///   - event: Event name
    ///   - parameters: Event parameters
    func trackEvent(_ event: String, parameters: [String: Any] = [:]) {
        guard isEnabled else { return }
        
        // Log event for debugging
        logger.info("Event: \(event), Parameters: \(parameters)")
        
        // In production, send to analytics service
        // Example: Firebase Analytics, Mixpanel, etc.
        sendToAnalyticsService(event: event, parameters: parameters)
    }
    
    /// Track user action
    /// - Parameters:
    ///   - action: Action name
    ///   - screen: Screen name
    ///   - additionalInfo: Additional information
    func trackUserAction(_ action: String, screen: String, additionalInfo: [String: Any] = [:]) {
        var parameters = additionalInfo
        parameters["screen"] = screen
        parameters["timestamp"] = Date().timeIntervalSince1970
        
        trackEvent("user_action", parameters: parameters)
    }
    
    /// Track error
    /// - Parameters:
    ///   - error: Error description
    ///   - context: Error context
    ///   - severity: Error severity
    func trackError(_ error: String, context: String, severity: ErrorSeverity = .medium) {
        let parameters: [String: Any] = [
            "error": error,
            "context": context,
            "severity": severity.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        trackEvent("error", parameters: parameters)
        
        // Log error for debugging
        logger.error("Error: \(error), Context: \(context), Severity: \(severity.rawValue)")
    }
    
    /// Track performance metric
    /// - Parameters:
    ///   - metric: Metric name
    ///   - value: Metric value
    ///   - unit: Metric unit
    func trackPerformance(_ metric: String, value: Double, unit: String = "ms") {
        let parameters: [String: Any] = [
            "metric": metric,
            "value": value,
            "unit": unit,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        trackEvent("performance", parameters: parameters)
    }
    
    /// Track security event
    /// - Parameters:
    ///   - event: Security event
    ///   - details: Event details
    func trackSecurityEvent(_ event: String, details: [String: Any] = [:]) {
        var parameters = details
        parameters["event_type"] = "security"
        parameters["timestamp"] = Date().timeIntervalSince1970
        
        trackEvent("security_event", parameters: parameters)
        
        // Log security events with higher priority
        logger.warning("Security Event: \(event), Details: \(details)")
    }
    
    /// Track user engagement
    /// - Parameters:
    ///   - feature: Feature name
    ///   - duration: Time spent
    ///   - success: Whether the action was successful
    func trackEngagement(_ feature: String, duration: TimeInterval, success: Bool) {
        let parameters: [String: Any] = [
            "feature": feature,
            "duration": duration,
            "success": success,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        trackEvent("engagement", parameters: parameters)
    }
    
    /// Enable or disable analytics
    /// - Parameter enabled: Whether analytics should be enabled
    func setAnalyticsEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "analytics_enabled")
        
        if enabled {
            trackEvent("analytics_enabled")
        }
    }
    
    /// Check if analytics is enabled
    var isAnalyticsEnabled: Bool {
        return isEnabled
    }
    
    // MARK: - Private Methods
    
    private func checkAnalyticsConsent() {
        // Check user consent for analytics
        let consent = UserDefaults.standard.object(forKey: "analytics_consent") as? Bool
        if let consent = consent {
            isEnabled = consent
        } else {
            // Default to enabled, but user can opt out
            isEnabled = true
        }
    }
    
    private func sendToAnalyticsService(event: String, parameters: [String: Any]) {
        // In production, implement actual analytics service integration
        // Examples:
        // - Firebase Analytics
        // - Mixpanel
        // - Amplitude
        // - Custom analytics endpoint
        
        #if DEBUG
        print("📊 Analytics Event: \(event)")
        print("📊 Parameters: \(parameters)")
        #endif
    }
}

/// Error severity levels
enum ErrorSeverity: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

/// Common analytics events
struct AnalyticsEvents {
    static let appLaunch = "app_launch"
    static let appBackground = "app_background"
    static let appForeground = "app_foreground"
    static let userLogin = "user_login"
    static let userLogout = "user_logout"
    static let scanStarted = "scan_started"
    static let scanCompleted = "scan_completed"
    static let scanFailed = "scan_failed"
    static let mfaSetup = "mfa_setup"
    static let mfaEnabled = "mfa_enabled"
    static let dataExport = "data_export"
    static let dataDeletion = "data_deletion"
    static let permissionRequested = "permission_requested"
    static let permissionGranted = "permission_granted"
    static let permissionDenied = "permission_denied"
}

/// View modifier for automatic analytics tracking
struct AnalyticsViewModifier: ViewModifier {
    let screenName: String
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                AnalyticsManager.shared.trackUserAction("screen_view", screen: screenName)
            }
    }
}

extension View {
    /// Add analytics tracking to a view
    /// - Parameter screenName: Name of the screen
    /// - Returns: Modified view with analytics tracking
    func trackScreen(_ screenName: String) -> some View {
        self.modifier(AnalyticsViewModifier(screenName: screenName))
    }
}
