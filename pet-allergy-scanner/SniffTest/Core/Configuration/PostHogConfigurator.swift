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
        let host = Configuration.postHogHost
        
        guard !apiKey.isEmpty else {
            logger.error("PostHog API key is empty. Update Info.plist with POSTHOG_API_KEY before shipping.")
            return
        }
        
        let config = PostHogConfig(apiKey: apiKey, host: host)
        
        // Enable debug mode in development for verbose logging
        #if DEBUG
        config.debug = true
        #endif
        
        // Enable session replay for user session recording
        config.sessionReplay = true
        config.sessionReplayConfig.screenshotMode = true // Required for SwiftUI compatibility
        
        // Enable additional tracking for better analytics
        config.captureApplicationLifecycleEvents = true // Track app open/close events
        config.captureScreenViews = true // Track screen view changes
        config.captureElementInteractions = true // Enable autocapture of user interactions
        
        PostHogSDK.shared.setup(config)
        
        logger.info("PostHog configured with host: \(host), session replay enabled")
    }
    
    // Note: Additional PostHog methods (identify, track, reset) can be called directly
    // via PostHogSDK.shared once the exact API signatures are verified.
    // Refer to PostHog iOS SDK documentation for the correct method signatures.
}

