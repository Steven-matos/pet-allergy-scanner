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
        
        // Enable session replay for user session recording
        // Note: Session replay may have URL construction issues in some SDK versions
        // If you see "bad URL" errors with /s/? endpoint, try disabling session replay
        // by setting config.sessionReplay = false
        config.sessionReplay = true
        config.sessionReplayConfig.screenshotMode = true // Required for SwiftUI compatibility
        
        // Limit session replay to reduce data usage and potential errors
        config.sessionReplayConfig.maskAllTextInputs = true // Mask sensitive input
        config.sessionReplayConfig.maskAllImages = false // Allow images for better debugging
        
        // Enable additional tracking for better analytics
        config.captureApplicationLifecycleEvents = true // Track app open/close events
        config.captureScreenViews = true // Track screen view changes
        config.captureElementInteractions = true // Enable autocapture of user interactions
        
        // Configure PostHog SDK
        // Note: PostHog SDK setup doesn't throw, so errors are handled internally
        PostHogSDK.shared.setup(config)
        logger.info("PostHog configured successfully with host: \(host), session replay enabled")
    }
    
    // Note: Additional PostHog methods (identify, track, reset) can be called directly
    // via PostHogSDK.shared once the exact API signatures are verified.
    // Refer to PostHog iOS SDK documentation for the correct method signatures.
}

