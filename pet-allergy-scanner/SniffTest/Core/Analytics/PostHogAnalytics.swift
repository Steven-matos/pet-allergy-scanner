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
enum PostHogAnalytics {
    private static let logger = Logger(subsystem: "com.snifftest.app", category: "Analytics")
    
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
        
        PostHogSDK.shared.identify(user.id, userProperties: properties)
        logger.info("PostHog user identified: \(user.id)")
    }
    
    /// Reset user identification
    /// Call this when user logs out
    static func resetUser() {
        PostHogSDK.shared.reset()
        logger.info("PostHog user reset")
    }
    
    /// Update user properties
    /// - Parameter properties: Dictionary of user properties to update
    static func updateUserProperties(_ properties: [String: Any]) {
        PostHogSDK.shared.identify(PostHogSDK.shared.getDistinctId(), userProperties: properties)
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
    /// - Parameters:
    ///   - eventName: The name of the event
    ///   - properties: Optional dictionary of event properties
    private static func trackEvent(_ eventName: String, properties: [String: Any]? = nil) {
        PostHogSDK.shared.capture(eventName, properties: properties)
        logger.debug("Analytics event tracked: \(eventName)")
    }
}

