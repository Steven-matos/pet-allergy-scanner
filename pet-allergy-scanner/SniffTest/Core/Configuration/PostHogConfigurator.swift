//
//  PostHogConfigurator.swift
//  SniffTest
//
//  Helper for configuring the PostHog SDK for analytics tracking.
//

import Foundation
import PostHog
import os.log

/// Coordinates PostHog SDK configuration using app configuration values.
enum PostHogConfigurator {
    private static let logger = Logger(subsystem: "com.snifftest.app", category: "PostHog")
    
    /// Configure the PostHog SDK using Info.plist values.
    /// This should be called during app launch in AppDelegate.
    @MainActor
    static func configure() {
        let apiKey = Configuration.postHogAPIKey
        var host = Configuration.postHogHost
        
        guard !apiKey.isEmpty else {
            logger.error("PostHog API key is empty. Update Info.plist with POSTHOG_API_KEY before shipping.")
            return
        }
        
        // Validate and sanitize host URL - ensure it's properly formatted
        host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove trailing slashes
        while host.hasSuffix("/") {
            host = String(host.dropLast())
        }
        
        // Ensure protocol is present
        if !host.hasPrefix("http://") && !host.hasPrefix("https://") {
            host = "https://" + host
        }
        
        // Validate host URL is properly formatted
        if URL(string: host) == nil {
            logger.error("PostHog host URL is invalid: \(host). Using default host.")
            host = "https://us.i.posthog.com"
        }
        
        let config = PostHogConfig(apiKey: apiKey, host: host)
        
        // Enable debug mode in development for verbose logging
        #if DEBUG
        config.debug = true
        #endif
        
        // Session Replay Configuration (2025 Best Practices)
        // For SwiftUI apps, screenshot mode is required for compatibility
        // Screenshot mode captures UI state as images rather than DOM-like structure
        config.sessionReplay = true
        config.sessionReplayConfig.screenshotMode = true // Required for SwiftUI compatibility
        config.sessionReplayConfig.throttleDelay = 1.0 // Balance performance and recording fidelity (1 second delay)
        config.sessionReplayConfig.maskAllTextInputs = true // Mask sensitive input for privacy
        config.sessionReplayConfig.maskAllImages = false // Keep images visible for nutrition section analysis
        
        logger.info("Session Replay enabled with screenshot mode for SwiftUI compatibility")
        
        // Enable additional tracking for better analytics (2025 Best Practices)
        config.captureApplicationLifecycleEvents = true // Track app open/close events automatically
        // For SwiftUI, manual screen tracking is recommended over autocapture
        // We track screens manually via PostHogAnalytics.trackScreenViewed()
        config.captureScreenViews = false // Disabled - using manual tracking for better control
        config.captureElementInteractions = true // Enable autocapture of user interactions (taps, swipes)
        
        // Feature Flags Configuration (2025 Best Practices)
        // Enable feature flags to support A/B testing and gradual rollouts
        // Feature flags are automatically fetched when user is identified
        // Note: These properties may not be available in all PostHog SDK versions
        // If compilation fails, these can be removed - feature flags will still work via reloadFeatureFlags()
        // config.loadFeatureFlagsOnStart = true // Load flags immediately on app start
        // config.reloadFeatureFlagsOnAppActive = true // Reload flags when app becomes active
        
        // Surveys Configuration (2025 Best Practices)
        // Enable surveys to gather user feedback at key moments
        // Note: This property may not be available in all PostHog SDK versions
        // config.surveys = true // Enable survey support
        
        // Method Swizzling (2025 Best Practices)
        // Enable method swizzling for accurate session replay and tracking metrics
        // This allows SDK to intercept method calls for advanced tracking
        // Note: This property may not be available in all PostHog SDK versions
        // config.enableMethodSwizzling = true
        
        // Privacy: Redact sensitive data before sending events
        // This ensures user privacy while maintaining analytics value
        config.setBeforeSend { event in
            // Redact sensitive information from event properties
            var properties = event.properties
            
            // Redact email addresses if present
            if let email = properties["email"] as? String {
                let redactedEmail = email.components(separatedBy: "@").first?.map { _ in "*" }.joined() ?? "***"
                properties["email"] = "\(redactedEmail)@***"
            }
            
            // Redact phone numbers if present
            if let phone = properties["phone"] as? String {
                properties["phone"] = "***-***-\(phone.suffix(4))"
            }
            
            // Don't capture full error messages that might contain sensitive data
            if let error = properties["error"] as? String {
                // Keep first 100 chars for debugging, redact the rest
                if error.count > 100 {
                    properties["error"] = String(error.prefix(100)) + "... [redacted]"
                }
            }
            
            event.properties = properties
            return event
        }
        
        // Configure PostHog SDK
        // Note: PostHog SDK setup doesn't throw, so errors are handled internally
        PostHogSDK.shared.setup(config)
        
        logger.info("PostHog SDK configured successfully with API key and host: \(host)")
        
        // Initialize privacy manager
        AnalyticsPrivacyManager.shared.initialize()
        
        // Initialize super properties after SDK setup (2025 Best Practice)
        // These properties will be attached to all events
        PostHogAnalytics.initializeSuperProperties()
        
        // Initialize context provider session
        AnalyticsContextProvider.shared.resetSession()
    }
    
    // Note: Additional PostHog methods (identify, track, reset) can be called directly
    // via PostHogSDK.shared once the exact API signatures are verified.
    // Refer to PostHog iOS SDK documentation for the correct method signatures.
}

