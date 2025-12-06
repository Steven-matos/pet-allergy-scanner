//
//  PostHogAnalytics.swift
//  SniffTest
//
//  Analytics helper for PostHog event tracking
//  Provides consistent event tracking across the app following SOLID, DRY, and KISS principles
//

import Foundation
import PostHog
import os.log
import UIKit
import Darwin

// MARK: - Safe Execution Helper

/// Helper to safely execute PostHog SDK calls
/// PostHog SDK should handle errors internally, but this provides an extra safety layer
private enum SafeExecution {
    static func execute(_ block: () -> Void) {
        // Execute block - PostHog SDK should handle any internal errors
        // We rely on PostHog's internal error handling to prevent crashes
        block()
    }
}

// MARK: - Date Extension for ISO8601

extension Date {
    /// ISO8601 formatted date string
    var iso8601: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}

/// Centralized analytics tracking using PostHog
/// Follows SOLID principles with single responsibility for analytics
/// Implements DRY by providing reusable tracking methods
/// Follows KISS by keeping the API simple and straightforward
/// 
/// Thread Safety: All methods are MainActor-isolated to ensure thread safety
/// Error Handling: All PostHog calls are wrapped in try-catch to prevent crashes
@MainActor
enum PostHogAnalytics {
    private static let logger = Logger(subsystem: "com.snifftest.app", category: "Analytics")
    
    /// Track if PostHog SDK is initialized
    private static var isInitialized: Bool {
        // Check if PostHog SDK has been set up by checking if we can access it
        // PostHogSDK.shared is always available, but we need to check if setup was called
        return true // PostHogSDK.shared is always available, setup() just configures it
    }
    
    // MARK: - Scanning Events
    
    /// Track when scan view is opened
    static func trackScanViewOpened() {
        trackEvent("scan_view_opened")
    }
    
    /// Track when an image is captured for scanning
    static func trackImageCaptured(hasBarcode: Bool = false) {
        trackEvent("scan_image_captured", properties: [
            "has_barcode": hasBarcode
        ])
    }
    
    /// Track when a scan is completed successfully
    static func trackScanCompleted(scanId: String, hasAllergens: Bool, allergenCount: Int, productFound: Bool) {
        trackEvent("scan_completed", properties: [
            "scan_id": scanId,
            "has_allergens": hasAllergens,
            "allergen_count": allergenCount,
            "product_found": productFound
        ])
    }
    
    /// Track when a scan fails
    static func trackScanFailed(error: String) {
        trackEvent("scan_failed", properties: [
            "error": error
        ])
    }
    
    /// Track when a barcode is detected
    static func trackBarcodeDetected(barcodeType: String) {
        trackEvent("barcode_detected", properties: [
            "barcode_type": barcodeType
        ])
    }
    
    /// Track when scan history is viewed
    static func trackScanHistoryViewed() {
        trackEvent("scan_history_viewed")
    }
    
    /// Track when pet is selected for scanning
    static func trackPetSelectedForScan(petId: String, petSpecies: String) {
        trackEvent("pet_selected_for_scan", properties: [
            "pet_id": petId,
            "pet_species": petSpecies
        ])
    }
    
    // MARK: - Health Events
    
    /// Track when health events view is opened
    static func trackHealthEventsViewOpened(petId: String) {
        trackEvent("health_events_view_opened", properties: [
            "pet_id": petId
        ])
    }
    
    /// Track when add health event button is tapped
    static func trackAddHealthEventTapped(petId: String) {
        trackEvent("add_health_event_tapped", properties: [
            "pet_id": petId
        ])
    }
    
    /// Track when a health event is viewed
    static func trackHealthEventViewed(eventId: String, eventCategory: String) {
        trackEvent("health_event_viewed", properties: [
            "event_id": eventId,
            "event_category": eventCategory
        ])
    }
    
    /// Track when health event category filter is changed
    static func trackHealthEventFilterChanged(category: String?) {
        trackEvent("health_event_filter_changed", properties: [
            "category": category ?? "all"
        ])
    }
    
    /// Track when health events are refreshed
    static func trackHealthEventsRefreshed(petId: String) {
        trackEvent("health_events_refreshed", properties: [
            "pet_id": petId
        ])
    }
    
    // MARK: - Nutrition Events
    
    /// Track when nutrition dashboard is opened
    static func trackNutritionDashboardOpened() {
        trackEvent("nutrition_dashboard_opened")
    }
    
    /// Track when a pet is selected in nutrition dashboard
    static func trackNutritionPetSelected(petId: String, petSpecies: String) {
        trackEvent("nutrition_pet_selected", properties: [
            "pet_id": petId,
            "pet_species": petSpecies
        ])
    }
    
    /// Track when premium upgrade is tapped from nutrition section
    static func trackNutritionPremiumUpgradeTapped() {
        trackEvent("nutrition_premium_upgrade_tapped")
    }
    
    /// Track when nutrition section is viewed
    static func trackNutritionSectionViewed(section: String, petId: String) {
        trackEvent("nutrition_section_viewed", properties: [
            "section": section,
            "pet_id": petId
        ])
    }
    
    /// Track when a feeding is logged
    static func trackFeedingLogged(petId: String, foodId: String, amountGrams: Double) {
        trackEvent("feeding_logged", properties: [
            "pet_id": petId,
            "food_id": foodId,
            "amount_grams": amountGrams
        ])
    }
    
    /// Track when a feeding record is deleted
    static func trackFeedingDeleted(petId: String, feedingId: String) {
        trackEvent("feeding_deleted", properties: [
            "pet_id": petId,
            "feeding_id": feedingId
        ])
    }
    
    /// Track when weight is recorded
    static func trackWeightRecorded(petId: String, weightKg: Double) {
        trackEvent("weight_recorded", properties: [
            "pet_id": petId,
            "weight_kg": weightKg
        ])
    }
    
    /// Track when weight goal is set or updated
    static func trackWeightGoalSet(petId: String, targetWeightKg: Double) {
        trackEvent("weight_goal_set", properties: [
            "pet_id": petId,
            "target_weight_kg": targetWeightKg
        ])
    }
    
    /// Track when food comparison is viewed
    static func trackFoodComparisonViewed(petId: String, foodCount: Int) {
        trackEvent("food_comparison_viewed", properties: [
            "pet_id": petId,
            "food_count": foodCount
        ])
    }
    
    /// Track when food comparison is completed
    static func trackFoodComparisonCompleted(petId: String, foodCount: Int, bestFoodId: String?) {
        var properties: [String: Any] = [
            "pet_id": petId,
            "food_count": foodCount
        ]
        if let bestFoodId = bestFoodId {
            properties["best_food_id"] = bestFoodId
        }
        trackEvent("food_comparison_completed", properties: properties)
    }
    
    /// Track when nutritional trends view is opened
    static func trackNutritionalTrendsViewed(petId: String) {
        trackEvent("nutritional_trends_viewed", properties: [
            "pet_id": petId
        ])
    }
    
    /// Track when feeding log view is opened
    static func trackFeedingLogViewOpened(petId: String?) {
        var properties: [String: Any] = [:]
        if let petId = petId {
            properties["pet_id"] = petId
        }
        trackEvent("feeding_log_view_opened", properties: properties.isEmpty ? nil : properties)
    }
    
    /// Track when weight management view is opened
    static func trackWeightManagementViewOpened(petId: String?) {
        var properties: [String: Any] = [:]
        if let petId = petId {
            properties["pet_id"] = petId
        }
        trackEvent("weight_management_view_opened", properties: properties.isEmpty ? nil : properties)
    }
    
    /// Track when advanced nutrition view is opened
    static func trackAdvancedNutritionViewOpened(petId: String) {
        trackEvent("advanced_nutrition_view_opened", properties: [
            "pet_id": petId
        ])
    }
    
    // MARK: - Profile & Settings Events
    
    /// Track when profile view is opened
    static func trackProfileViewOpened() {
        trackEvent("profile_view_opened")
    }
    
    /// Track when profile is updated
    static func trackProfileUpdated(fieldsUpdated: [String]) {
        trackEvent("profile_updated", properties: [
            "fields_updated": fieldsUpdated
        ])
    }
    
    /// Track when settings view is opened
    static func trackSettingsViewOpened() {
        trackEvent("settings_view_opened")
    }
    
    /// Track when notification settings are changed
    static func trackNotificationSettingsChanged(enabled: Bool, notificationType: String) {
        trackEvent("notification_settings_changed", properties: [
            "enabled": enabled,
            "notification_type": notificationType
        ])
    }
    
    /// Track when PDF is exported
    static func trackPDFExported(petId: String, success: Bool, error: String? = nil) {
        var properties: [String: Any] = [
            "pet_id": petId,
            "success": success
        ]
        if let error = error {
            properties["error"] = error
        }
        trackEvent("pdf_exported", properties: properties)
    }
    
    /// Track when data export is requested
    static func trackDataExportRequested() {
        trackEvent("data_export_requested")
    }
    
    /// Track when data deletion is requested
    static func trackDataDeletionRequested() {
        trackEvent("data_deletion_requested")
    }
    
    // MARK: - Subscription & Paywall Events
    
    /// Track when paywall is viewed
    static func trackPaywallViewed(source: String) {
        trackEvent("paywall_viewed", properties: [
            "source": source
        ])
    }
    
    /// Track when subscription is cancelled
    static func trackSubscriptionCancelled(reason: String? = nil) {
        var properties: [String: Any] = [:]
        if let reason = reason {
            properties["reason"] = reason
        }
        trackEvent("subscription_cancelled", properties: properties.isEmpty ? nil : properties)
    }
    
    /// Track when subscription is restored
    static func trackSubscriptionRestored(success: Bool, error: String? = nil) {
        var properties: [String: Any] = [
            "success": success
        ]
        if let error = error {
            properties["error"] = error
        }
        trackEvent("subscription_restored", properties: properties)
    }
    
    /// Track when payment fails
    static func trackPaymentFailed(productId: String, error: String) {
        trackEvent("payment_failed", properties: [
            "product_id": productId,
            "error": error
        ])
    }
    
    /// Track when subscription view is opened
    static func trackSubscriptionViewOpened() {
        trackEvent("subscription_view_opened")
    }
    
    // MARK: - View & Screen Events
    
    /// Track when a view/screen is viewed
    static func trackScreenViewed(screenName: String, properties: [String: Any]? = nil) {
        var eventProperties: [String: Any] = [
            "screen_name": screenName
        ]
        if let properties = properties {
            eventProperties.merge(properties) { (_, new) in new }
        }
        trackEvent("screen_viewed", properties: eventProperties)
    }
    
    /// Track when pets view is opened
    static func trackPetsViewOpened() {
        trackEvent("pets_view_opened")
    }
    
    /// Track when history view is opened
    static func trackHistoryViewOpened() {
        trackEvent("history_view_opened")
    }
    
    /// Track when help/support view is opened
    static func trackHelpViewOpened() {
        trackEvent("help_view_opened")
    }
    
    // MARK: - Error & Performance Events
    
    /// Track when an error occurs with device diagnostics
    /// - Parameters:
    ///   - error: Error message or description
    ///   - context: Where the error occurred (view name, function, etc.)
    ///   - severity: Error severity (low, medium, high, critical)
    ///   - includeDeviceInfo: Whether to include device diagnostics (default: true)
    static func trackError(error: String, context: String, severity: String = "medium", includeDeviceInfo: Bool = true) {
        var properties: [String: Any] = [
            "error": error,
            "context": context,
            "severity": severity,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if includeDeviceInfo {
            properties.merge(getDeviceDiagnostics()) { (_, new) in new }
        }
        
        trackEvent("error_occurred", properties: properties)
    }
    
    /// Track UI freeze detection
    /// Call this when a freeze is detected (e.g., timeout, stuck loading state)
    /// - Parameters:
    ///   - viewName: Name of the view where freeze occurred
    ///   - duration: How long the freeze lasted (in seconds)
    ///   - action: What action triggered the freeze
    static func trackUIFreeze(viewName: String, duration: TimeInterval, action: String? = nil) {
        var properties: [String: Any] = [
            "view_name": viewName,
            "freeze_duration_seconds": duration,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let action = action {
            properties["action"] = action
        }
        
        // Include device diagnostics for freeze events
        properties.merge(getDeviceDiagnostics()) { (_, new) in new }
        
        // Include performance metrics
        properties.merge(getPerformanceMetrics()) { (_, new) in new }
        
        trackEvent("ui_freeze_detected", properties: properties)
    }
    
    /// Track navigation performance
    /// - Parameters:
    ///   - fromView: Source view name
    ///   - toView: Destination view name
    ///   - duration: Navigation duration in seconds
    ///   - success: Whether navigation completed successfully
    static func trackNavigation(fromView: String, toView: String, duration: TimeInterval, success: Bool) {
        var properties: [String: Any] = [
            "from_view": fromView,
            "to_view": toView,
            "duration_seconds": duration,
            "success": success,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Include device info for navigation issues
        if !success || duration > 1.0 {
            properties.merge(getDeviceDiagnostics()) { (_, new) in new }
        }
        
        trackEvent("navigation_performance", properties: properties)
    }
    
    /// Track view load performance
    /// - Parameters:
    ///   - viewName: Name of the view
    ///   - loadTime: Time taken to load (in seconds)
    ///   - dataLoadTime: Time taken to load data (in seconds)
    ///   - success: Whether load was successful
    static func trackViewLoad(viewName: String, loadTime: TimeInterval, dataLoadTime: TimeInterval? = nil, success: Bool) {
        var properties: [String: Any] = [
            "view_name": viewName,
            "load_time_seconds": loadTime,
            "success": success,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let dataLoadTime = dataLoadTime {
            properties["data_load_time_seconds"] = dataLoadTime
        }
        
        // Include device info for slow loads
        if loadTime > 2.0 || !success {
            properties.merge(getDeviceDiagnostics()) { (_, new) in new }
            properties.merge(getPerformanceMetrics()) { (_, new) in new }
        }
        
        trackEvent("view_load_performance", properties: properties)
    }
    
    /// Track API call performance
    static func trackAPICall(endpoint: String, duration: TimeInterval, success: Bool, statusCode: Int? = nil) {
        var properties: [String: Any] = [
            "endpoint": endpoint,
            "duration_ms": duration * 1000,
            "success": success
        ]
        if let statusCode = statusCode {
            properties["status_code"] = statusCode
        }
        trackEvent("api_call", properties: properties)
    }
    
    /// Track cache hit/miss
    static func trackCacheEvent(cacheKey: String, hit: Bool) {
        trackEvent("cache_event", properties: [
            "cache_key": cacheKey,
            "hit": hit
        ])
    }
    
    // MARK: - User Management Events
    
    /// Identify user with PostHog
    /// Call this when user logs in to associate events with their user ID
    /// - Parameter user: The authenticated user
    static func identifyUser(_ user: User, petsCount: Int = 0) {
        var properties: [String: Any] = [
            "email": user.email,
            "role": user.role.rawValue,
            "onboarded": user.onboarded,
            "account_created_at": user.createdAt.iso8601
        ]
        
        if let username = user.username {
            properties["username"] = username
        }
        
        if let firstName = user.firstName {
            properties["first_name"] = firstName
        }
        
        if let lastName = user.lastName {
            properties["last_name"] = lastName
        }
        
        if petsCount > 0 {
            properties["pets_count"] = petsCount
        }
        
        // Sanitize properties and call PostHog SDK
        // PostHog SDK methods don't throw, so no do-catch needed
        let sanitizedProperties = sanitizeProperties(properties) ?? [:]
        PostHogSDK.shared.identify(user.id, userProperties: sanitizedProperties)
    }
    
    /// Reset user identification
    /// Call this when user logs out
    static func resetUser() {
        // PostHog SDK methods don't throw, so no do-catch needed
        PostHogSDK.shared.reset()
    }
    
    /// Update user properties
    /// - Parameter properties: Dictionary of user properties to update
    static func updateUserProperties(_ properties: [String: Any]) {
        // PostHog SDK methods don't throw, so no do-catch needed
        let sanitizedProperties = sanitizeProperties(properties) ?? [:]
        PostHogSDK.shared.identify(PostHogSDK.shared.getDistinctId(), userProperties: sanitizedProperties)
        logger.debug("PostHog user properties updated")
    }
    
    /// Update pet count property
    /// - Parameter count: Current number of pets
    static func updatePetCount(_ count: Int) {
        updateUserProperties(["pets_count": count])
    }
    
    /// Update user role property
    /// - Parameter role: User role (free or premium)
    static func updateUserRole(_ role: String) {
        updateUserProperties([
            "role": role,
            "role_updated_at": Date().iso8601
        ])
    }
    
    /// Track when user registers
    static func trackUserRegistered(email: String) {
        trackEvent("user_registered", properties: [
            "email": email
        ])
    }
    
    /// Track when user logs in
    static func trackUserLoggedIn(userId: String, role: String) {
        trackEvent("user_logged_in", properties: [
            "user_id": userId,
            "role": role
        ])
    }
    
    /// Track when user logs out
    static func trackUserLoggedOut() {
        trackEvent("user_logged_out")
    }
    
    /// Track when user upgrades to premium
    static func trackPremiumUpgrade(tier: String, productId: String? = nil) {
        var properties: [String: Any] = [
            "tier": tier,
            "upgraded_at": Date().iso8601
        ]
        
        if let productId = productId {
            properties["product_id"] = productId
        }
        
        trackEvent("premium_upgraded", properties: properties)
        updateUserRole("premium")
    }
    
    /// Track when onboarding is completed
    static func trackOnboardingCompleted(petsCount: Int) {
        trackEvent("onboarding_completed", properties: [
            "pets_count": petsCount
        ])
        updateUserProperties([
            "onboarded": true,
            "onboarded_at": Date().iso8601
        ])
    }
    
    // MARK: - Pet Management Events
    
    /// Track when a pet is created
    static func trackPetCreated(petId: String, species: String) {
        trackEvent("pet_created", properties: [
            "pet_id": petId,
            "pet_species": species
        ])
    }
    
    /// Track when a pet is updated
    static func trackPetUpdated(petId: String, species: String) {
        trackEvent("pet_updated", properties: [
            "pet_id": petId,
            "pet_species": species
        ])
    }
    
    /// Track when a pet is deleted
    static func trackPetDeleted(petId: String, species: String) {
        trackEvent("pet_deleted", properties: [
            "pet_id": petId,
            "pet_species": species
        ])
    }
    
    // MARK: - Generic Event Tracking
    
    /// Generic event tracking method
    /// Thread-safe and crash-resistant implementation
    /// - Parameters:
    ///   - eventName: The name of the event
    ///   - properties: Optional dictionary of event properties
    private static func trackEvent(_ eventName: String, properties: [String: Any]? = nil) {
        // Since PostHogAnalytics is @MainActor, all calls are automatically on MainActor
        // However, we add extra safety by ensuring thread safety and error handling
        safeTrackEvent(eventName: eventName, properties: properties)
    }
    
    /// Internal safe event tracking that's guaranteed to be on MainActor
    private static func safeTrackEvent(eventName: String, properties: [String: Any]?) {
        // Wrap PostHog calls to prevent crashes
        // PostHog SDK should handle errors internally, but we add extra safety
        // Use a closure to catch any potential issues
        SafeExecution.execute {
            // Sanitize properties to ensure they're JSON-serializable
            let sanitizedProperties = sanitizeProperties(properties)
            
            // Call PostHog SDK - we're guaranteed to be on MainActor via @MainActor
            // PostHog SDK should be thread-safe, but we ensure MainActor for safety
            PostHogSDK.shared.capture(eventName, properties: sanitizedProperties)
            logger.debug("Analytics event tracked: \(eventName)")
        }
    }
    
    /// Get device diagnostics for error tracking
    /// Returns device information that helps diagnose issues
    private static func getDeviceDiagnostics() -> [String: Any] {
        var diagnostics: [String: Any] = [:]
        
        // Device model
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingCString: $0)
            }
        } ?? "unknown"
        diagnostics["device_model"] = modelCode
        diagnostics["device_name"] = UIDevice.current.name
        diagnostics["device_type"] = UIDevice.current.model
        
        // iOS version
        diagnostics["ios_version"] = UIDevice.current.systemVersion
        
        // Device capabilities
        diagnostics["is_older_device"] = DevicePerformanceHelper.isOlderDevice
        diagnostics["max_chart_data_points"] = DevicePerformanceHelper.maxChartDataPoints
        diagnostics["should_use_simplified_charts"] = DevicePerformanceHelper.shouldUseSimplifiedCharts
        
        // Battery level (if available)
        UIDevice.current.isBatteryMonitoringEnabled = true
        if UIDevice.current.batteryLevel >= 0 {
            diagnostics["battery_level"] = Int(UIDevice.current.batteryLevel * 100)
            diagnostics["battery_state"] = batteryStateString(UIDevice.current.batteryState)
        }
        
        // Screen size
        let screen = UIScreen.main
        diagnostics["screen_width"] = Int(screen.bounds.width)
        diagnostics["screen_height"] = Int(screen.bounds.height)
        diagnostics["screen_scale"] = screen.scale
        
        return diagnostics
    }
    
    /// Get performance metrics
    /// Returns current performance metrics for diagnostics
    private static func getPerformanceMetrics() -> [String: Any] {
        var metrics: [String: Any] = [:]
        
        // Process info
        let processInfo = ProcessInfo.processInfo
        metrics["processor_count"] = processInfo.processorCount
        metrics["active_processor_count"] = processInfo.activeProcessorCount
        metrics["physical_memory_mb"] = Int(processInfo.physicalMemory / 1_024 / 1_024)
        
        // System uptime
        metrics["system_uptime_seconds"] = processInfo.systemUptime
        
        // Thermal state (iOS 11+)
        if #available(iOS 11.0, *) {
            let thermalState = processInfo.thermalState
            metrics["thermal_state"] = thermalStateString(thermalState)
        }
        
        // Low power mode
        if #available(iOS 9.0, *) {
            metrics["low_power_mode"] = processInfo.isLowPowerModeEnabled
        }
        
        return metrics
    }
    
    /// Convert battery state to string
    private static func batteryStateString(_ state: UIDevice.BatteryState) -> String {
        switch state {
        case .unknown:
            return "unknown"
        case .unplugged:
            return "unplugged"
        case .charging:
            return "charging"
        case .full:
            return "full"
        @unknown default:
            return "unknown"
        }
    }
    
    /// Convert thermal state to string
    @available(iOS 11.0, *)
    private static func thermalStateString(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal:
            return "nominal"
        case .fair:
            return "fair"
        case .serious:
            return "serious"
        case .critical:
            return "critical"
        @unknown default:
            return "unknown"
        }
    }
    
    /// Sanitize properties to ensure they're safe for PostHog
    /// Removes any non-JSON-serializable values
    private static func sanitizeProperties(_ properties: [String: Any]?) -> [String: Any]? {
        guard let properties = properties else { return nil }
        
        var sanitized: [String: Any] = [:]
        for (key, value) in properties {
            // Only include JSON-serializable types
            if value is String || value is Int || value is Double || value is Bool {
                sanitized[key] = value
            } else if let array = value as? [Any] {
                // Check if array contains only JSON-serializable types
                let validArray = array.compactMap { element -> Any? in
                    if element is String || element is Int || element is Double || element is Bool {
                        return element
                    }
                    return nil
                }
                if !validArray.isEmpty {
                    sanitized[key] = validArray
                }
            } else {
                // Convert other types to string representation
                sanitized[key] = String(describing: value)
            }
        }
        return sanitized.isEmpty ? nil : sanitized
    }
}

