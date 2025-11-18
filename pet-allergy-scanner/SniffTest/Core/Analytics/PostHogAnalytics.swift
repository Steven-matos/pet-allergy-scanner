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

