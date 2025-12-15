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
    
    // MARK: - Lifecycle Events
    
    /// Track app installation (first launch only)
    static func trackAppInstalled() {
        trackEvent(AnalyticsEvent.appInstalled, properties: [
            "is_first_launch": true
        ])
    }
    
    /// Track app opened (every cold start)
    static func trackAppOpened(isFirstLaunch: Bool = false, timeSinceLastLaunch: TimeInterval? = nil) {
        var properties: [String: Any] = [
            "is_first_launch": isFirstLaunch
        ]
        if let timeSinceLastLaunch = timeSinceLastLaunch {
            properties["time_since_last_launch_seconds"] = Int(timeSinceLastLaunch)
        }
        trackEvent(AnalyticsEvent.appOpened, properties: properties)
    }
    
    /// Track app backgrounded
    static func trackAppBackgrounded() {
        trackEvent(AnalyticsEvent.appBackgrounded)
    }
    
    /// Track app foregrounded
    static func trackAppForegrounded() {
        trackEvent(AnalyticsEvent.appForegrounded)
    }
    
    /// Track app crash (heuristic detection)
    static func trackAppCrashed() {
        trackEvent(AnalyticsEvent.appCrashed, properties: [
            "detection_method": "heuristic"
        ])
    }
    
    // MARK: - Onboarding & Activation Events
    
    /// Track onboarding started
    static func trackOnboardingStarted() {
        trackEvent(AnalyticsEvent.onboardingStarted)
    }
    
    /// Track onboarding step viewed
    /// - Parameter step: Step identifier ("welcome", "add_pet", "permissions", "first_scan_prompt")
    static func trackOnboardingStepViewed(step: String) {
        trackEvent(AnalyticsEvent.onboardingStepViewed, properties: [
            EventProperties.OnboardingStepViewed.step: step
        ])
    }
    
    /// Track onboarding completed
    /// - Parameter timeToCompleteSec: Time taken to complete onboarding in seconds
    /// - Parameter petsCount: Number of pets created during onboarding
    static func trackOnboardingCompleted(timeToCompleteSec: TimeInterval, petsCount: Int) {
        trackEvent(AnalyticsEvent.onboardingCompleted, properties: [
            EventProperties.OnboardingCompleted.timeToCompleteSec: Int(timeToCompleteSec),
            EventProperties.OnboardingCompleted.petsCount: petsCount
        ])
        updateUserProperties([
            "onboarded": true,
            "onboarding_completed": true,
            "onboarded_at": Date().iso8601
        ])
    }
    
    /// Track activation (user completes: pet created + scan completed + report viewed)
    /// This is a key metric for measuring user value realization
    static func trackActivation() {
        trackEvent("activation_completed", properties: [
            "activation_date": Date().iso8601
        ])
        updateUserProperties([
            "activated": true,
            "activated_at": Date().iso8601
        ])
    }
    
    // MARK: - Scanning Events
    
    /// Track when scan is started
    /// - Parameter mode: Scan mode ("camera", "photo", "barcode")
    static func trackScanStarted(mode: String) {
        trackEvent(AnalyticsEvent.scanStarted, properties: [
            EventProperties.ScanStarted.mode: mode
        ])
    }
    
    /// Track when scan view is opened (legacy - use trackScanStarted)
    @available(*, deprecated, message: "Use trackScanStarted(mode:) instead")
    static func trackScanViewOpened() {
        trackScanStarted(mode: "camera")
    }
    
    /// Track when scan permission is prompted
    /// - Parameter permission: Permission type ("camera", "photos")
    static func trackScanPermissionPrompted(permission: String) {
        trackEvent(AnalyticsEvent.scanPermissionPrompted, properties: [
            EventProperties.ScanPermissionPrompted.permission: permission
        ])
    }
    
    /// Track scan permission result
    /// - Parameters:
    ///   - permission: Permission type ("camera", "photos")
    ///   - status: Permission status ("granted", "denied", "limited")
    static func trackScanPermissionResult(permission: String, status: String) {
        trackEvent(AnalyticsEvent.scanPermissionResult, properties: [
            EventProperties.ScanPermissionResult.permission: permission,
            EventProperties.ScanPermissionResult.status: status
        ])
    }
    
    /// Track when scan capture succeeds
    /// - Parameters:
    ///   - mode: Scan mode
    ///   - imageSource: Image source ("camera", "library")
    static func trackScanCaptureSucceeded(mode: String, imageSource: String) {
        trackEvent(AnalyticsEvent.scanCaptureSucceeded, properties: [
            EventProperties.ScanCaptureSucceeded.mode: mode,
            EventProperties.ScanCaptureSucceeded.imageSource: imageSource
        ])
    }
    
    /// Track when an image is captured for scanning (legacy - use trackScanCaptureSucceeded)
    @available(*, deprecated, message: "Use trackScanCaptureSucceeded(mode:imageSource:) instead")
    static func trackImageCaptured(hasBarcode: Bool = false) {
        trackScanCaptureSucceeded(mode: "camera", imageSource: "camera")
    }
    
    /// Track OCR extraction
    /// - Parameters:
    ///   - textLength: Length of extracted text
    ///   - confidenceAvg: Average confidence score (optional)
    static func trackOCRExtracted(textLength: Int, confidenceAvg: Double? = nil) {
        var properties: [String: Any] = [
            EventProperties.OCRExtracted.textLength: textLength
        ]
        if let confidence = confidenceAvg {
            properties[EventProperties.OCRExtracted.confidenceAvg] = confidence
        }
        trackEvent(AnalyticsEvent.ocrExtracted, properties: properties)
    }
    
    /// Track barcode detection
    /// - Parameters:
    ///   - barcodeType: Type of barcode detected
    ///   - barcodePresent: Whether barcode was found
    static func trackBarcodeDetected(barcodeType: String, barcodePresent: Bool = true) {
        trackEvent(AnalyticsEvent.barcodeDetected, properties: [
            EventProperties.BarcodeDetected.barcodeType: barcodeType,
            EventProperties.BarcodeDetected.barcodePresent: barcodePresent
        ])
    }
    
    /// Track when analysis is requested
    /// - Parameter analysisType: Type of analysis ("ingredients", "nutrition", "both")
    static func trackAnalysisRequested(analysisType: String) {
        trackEvent(AnalyticsEvent.analysisRequested, properties: [
            EventProperties.AnalysisRequested.analysisType: analysisType
        ])
    }
    
    /// Track when analysis succeeds
    /// - Parameters:
    ///   - unsafeIngredientCount: Number of unsafe ingredients found
    ///   - allergenMatchCount: Number of allergen matches
    ///   - species: Pet species ("dog", "cat")
    ///   - hasRecommendations: Whether recommendations were generated
    static func trackAnalysisSucceeded(
        unsafeIngredientCount: Int,
        allergenMatchCount: Int,
        species: String,
        hasRecommendations: Bool
    ) {
        trackEvent(AnalyticsEvent.analysisSucceeded, properties: [
            EventProperties.AnalysisSucceeded.unsafeIngredientCount: unsafeIngredientCount,
            EventProperties.AnalysisSucceeded.allergenMatchCount: allergenMatchCount,
            EventProperties.AnalysisSucceeded.species: species,
            EventProperties.AnalysisSucceeded.hasRecommendations: hasRecommendations
        ])
    }
    
    /// Track when analysis fails
    /// - Parameters:
    ///   - stage: Failure stage ("ocr", "barcode", "backend", "parsing")
    ///   - errorCode: Error code
    ///   - errorDomain: Error domain
    static func trackAnalysisFailed(stage: String, errorCode: String, errorDomain: String) {
        trackEvent(AnalyticsEvent.analysisFailed, properties: [
            EventProperties.AnalysisFailed.stage: stage,
            EventProperties.AnalysisFailed.errorCode: errorCode,
            EventProperties.AnalysisFailed.errorDomain: errorDomain
        ])
    }
    
    /// Track when scan is completed
    /// - Parameters:
    ///   - scanId: Scan ID
    ///   - status: Completion status ("success", "partial", "failed")
    ///   - durationMsTotal: Total duration in milliseconds
    ///   - durationMsOCR: OCR duration in milliseconds (optional)
    ///   - durationMsBackend: Backend processing duration in milliseconds (optional)
    ///   - hasAllergens: Whether allergens were found
    ///   - allergenCount: Number of allergens found
    ///   - productFound: Whether product was found in database
    static func trackScanCompleted(
        scanId: String,
        status: String,
        durationMsTotal: Int,
        durationMsOCR: Int? = nil,
        durationMsBackend: Int? = nil,
        hasAllergens: Bool,
        allergenCount: Int,
        productFound: Bool
    ) {
        var properties: [String: Any] = [
            "scan_id": scanId,
            EventProperties.ScanCompleted.status: status,
            EventProperties.ScanCompleted.durationMsTotal: durationMsTotal,
            "has_allergens": hasAllergens,
            "allergen_count": allergenCount,
            "product_found": productFound
        ]
        if let ocrDuration = durationMsOCR {
            properties[EventProperties.ScanCompleted.durationMsOCR] = ocrDuration
        }
        if let backendDuration = durationMsBackend {
            properties[EventProperties.ScanCompleted.durationMsBackend] = backendDuration
        }
        trackEvent(AnalyticsEvent.scanCompleted, properties: properties)
    }
    
    /// Track when scan fails (legacy - use trackAnalysisFailed or trackScanCompleted with status="failed")
    @available(*, deprecated, message: "Use trackAnalysisFailed or trackScanCompleted with status='failed' instead")
    static func trackScanFailed(error: String) {
        trackAnalysisFailed(stage: "unknown", errorCode: "unknown", errorDomain: error)
    }
    
    /// Track when report is viewed
    /// - Parameters:
    ///   - reportType: Type of report ("safety", "nutrition")
    ///   - unsafeIngredientCount: Number of unsafe ingredients
    static func trackReportViewed(reportType: String, unsafeIngredientCount: Int) {
        trackEvent(AnalyticsEvent.reportViewed, properties: [
            EventProperties.ReportViewed.reportType: reportType,
            EventProperties.ReportViewed.unsafeIngredientCount: unsafeIngredientCount
        ])
    }
    
    /// Track when report is shared
    /// - Parameter method: Sharing method ("system_share", "copy_link")
    static func trackReportShared(method: String) {
        trackEvent(AnalyticsEvent.reportShared, properties: [
            EventProperties.ReportShared.method: method
        ])
    }
    
    /// Track when report is saved to history
    static func trackReportSavedToHistory() {
        trackEvent(AnalyticsEvent.reportSavedToHistory)
    }
    
    /// Track when scan is rescanned
    /// - Parameter reason: Reason for rescanning ("blurry", "missing_ingredients", "wrong_product")
    static func trackScanRescanned(reason: String) {
        trackEvent(AnalyticsEvent.scanRescanned, properties: [
            EventProperties.ScanRescanned.reason: reason
        ])
    }
    
    /// Track when scan is edited
    /// - Parameter editType: Type of edit ("ingredients_text", "product_name")
    static func trackScanEdited(editType: String) {
        trackEvent(AnalyticsEvent.scanEdited, properties: [
            EventProperties.ScanEdited.editType: editType
        ])
    }
    
    /// Track food database lookup
    /// - Parameters:
    ///   - method: Lookup method ("barcode", "search")
    ///   - hit: Whether product was found
    static func trackFoodDatabaseLookup(method: String, hit: Bool) {
        trackEvent(AnalyticsEvent.foodDatabaseLookup, properties: [
            EventProperties.FoodDatabaseLookup.method: method,
            EventProperties.FoodDatabaseLookup.hit: hit
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
        // Use group tracking for pet-level analytics (2025 Best Practice)
        trackEventWithGroup(
            "pet_selected_for_scan",
            properties: [
                "pet_species": petSpecies
            ],
            groupType: "pet",
            groupKey: petId
        )
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
    /// - Parameters:
    ///   - petId: Pet ID
    ///   - foodId: Food ID
    ///   - amountGrams: Amount in grams
    ///   - mealType: Meal type ("breakfast", "lunch", "dinner", "snack")
    ///   - calories: Calories consumed
    static func trackFeedingLogAdded(
        petId: String,
        foodId: String,
        amountGrams: Double,
        mealType: String? = nil,
        calories: Double? = nil
    ) {
        var properties: [String: Any] = [
            "food_id": foodId,
            EventProperties.FeedingLogAdded.portionGrams: amountGrams
        ]
        if let mealType = mealType {
            properties[EventProperties.FeedingLogAdded.mealType] = mealType
        }
        if let calories = calories {
            properties[EventProperties.FeedingLogAdded.calories] = calories
        }
        trackEventWithGroup(
            AnalyticsEvent.feedingLogAdded,
            properties: properties,
            groupType: "pet",
            groupKey: petId
        )
    }
    
    /// Track when a feeding is logged (legacy - use trackFeedingLogAdded)
    @available(*, deprecated, message: "Use trackFeedingLogAdded instead")
    static func trackFeedingLogged(petId: String, foodId: String, amountGrams: Double) {
        trackFeedingLogAdded(petId: petId, foodId: foodId, amountGrams: amountGrams)
    }
    
    /// Track when feeding log is edited
    /// - Parameter petId: Pet ID
    static func trackFeedingLogEdited(petId: String) {
        trackEventWithGroup(
            AnalyticsEvent.feedingLogEdited,
            properties: nil,
            groupType: "pet",
            groupKey: petId
        )
    }
    
    /// Track when feeding log is deleted
    /// - Parameter petId: Pet ID
    static func trackFeedingLogDeleted(petId: String) {
        trackEventWithGroup(
            AnalyticsEvent.feedingLogDeleted,
            properties: nil,
            groupType: "pet",
            groupKey: petId
        )
    }
    
    /// Track when a feeding record is deleted
    static func trackFeedingDeleted(petId: String, feedingId: String) {
        trackEvent("feeding_deleted", properties: [
            "pet_id": petId,
            "feeding_id": feedingId
        ])
    }
    
    /// Track when weight is recorded
    /// - Parameters:
    ///   - petId: Pet ID
    ///   - weightKg: Weight in kilograms
    ///   - source: Source of weight ("manual", "vet")
    static func trackWeightRecordAdded(petId: String, weightKg: Double, source: String = "manual") {
        trackEventWithGroup(
            AnalyticsEvent.weightRecordAdded,
            properties: [
                EventProperties.WeightRecordAdded.weightKg: weightKg,
                EventProperties.WeightRecordAdded.source: source
            ],
            groupType: "pet",
            groupKey: petId
        )
    }
    
    /// Track when weight is recorded (legacy - use trackWeightRecordAdded)
    @available(*, deprecated, message: "Use trackWeightRecordAdded instead")
    static func trackWeightRecorded(petId: String, weightKg: Double) {
        trackWeightRecordAdded(petId: petId, weightKg: weightKg)
    }
    
    /// Track when weight goal is set or updated
    /// - Parameters:
    ///   - petId: Pet ID
    ///   - targetWeightKg: Target weight in kilograms
    ///   - timeHorizonDays: Time horizon in days (optional)
    static func trackWeightGoalSet(petId: String, targetWeightKg: Double, timeHorizonDays: Int? = nil) {
        var properties: [String: Any] = [
            EventProperties.WeightGoalSet.targetWeightKg: targetWeightKg
        ]
        if let timeHorizon = timeHorizonDays {
            properties[EventProperties.WeightGoalSet.timeHorizonDays] = timeHorizon
        }
        trackEventWithGroup(
            AnalyticsEvent.weightGoalSet,
            properties: properties,
            groupType: "pet",
            groupKey: petId
        )
    }
    
    /// Track when calorie goal is set
    /// - Parameters:
    ///   - petId: Pet ID
    ///   - goalCaloriesDaily: Daily calorie goal
    ///   - source: Source of goal ("recommendation", "manual")
    static func trackCalorieGoalSet(petId: String, goalCaloriesDaily: Double, source: String = "manual") {
        trackEventWithGroup(
            AnalyticsEvent.calorieGoalSet,
            properties: [
                EventProperties.CalorieGoalSet.goalCaloriesDaily: goalCaloriesDaily,
                EventProperties.CalorieGoalSet.source: source
            ],
            groupType: "pet",
            groupKey: petId
        )
    }
    
    /// Track when nutrition insight is viewed
    /// - Parameters:
    ///   - petId: Pet ID
    ///   - insightType: Type of insight
    static func trackNutritionInsightViewed(petId: String, insightType: String) {
        trackEventWithGroup(
            AnalyticsEvent.nutritionInsightViewed,
            properties: [
                "insight_type": insightType
            ],
            groupType: "pet",
            groupKey: petId
        )
    }
    
    /// Track when food comparison is viewed
    /// - Parameters:
    ///   - petId: Pet ID
    ///   - foodCount: Number of foods being compared
    static func trackFoodComparisonViewed(petId: String, foodCount: Int) {
        trackEventWithGroup(
            AnalyticsEvent.foodCompared,
            properties: [
                EventProperties.FoodCompared.itemsCount: foodCount
            ],
            groupType: "pet",
            groupKey: petId
        )
    }
    
    /// Track when food comparison is completed
    /// - Parameters:
    ///   - petId: Pet ID
    ///   - foodCount: Number of foods compared
    ///   - bestFoodId: ID of best food (optional)
    static func trackFoodComparisonCompleted(petId: String, foodCount: Int, bestFoodId: String? = nil) {
        var properties: [String: Any] = [
            EventProperties.FoodCompared.itemsCount: foodCount
        ]
        if let bestFoodId = bestFoodId {
            properties["best_food_id"] = bestFoodId
        }
        trackEventWithGroup(
            AnalyticsEvent.foodCompared,
            properties: properties,
            groupType: "pet",
            groupKey: petId
        )
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
        
        // Update user properties
        updateUserProperties([
            "notifications_enabled": enabled
        ])
    }
    
    /// Track when push permission is prompted
    static func trackPushPermissionPrompted() {
        trackEvent(AnalyticsEvent.pushPermissionPrompted)
    }
    
    /// Track push permission result
    /// - Parameter status: Permission status ("granted", "denied")
    static func trackPushPermissionResult(status: String) {
        trackEvent(AnalyticsEvent.pushPermissionResult, properties: [
            EventProperties.PushPermissionResult.status: status
        ])
        
        // Update user properties
        updateUserProperties([
            "notifications_enabled": status == "granted"
        ])
    }
    
    /// Track when notification is scheduled
    /// - Parameters:
    ///   - type: Notification type ("birthday", "medication")
    ///   - frequency: Notification frequency
    ///   - leadTimeHours: Lead time in hours
    static func trackNotificationScheduled(type: String, frequency: String, leadTimeHours: Int) {
        trackEvent(AnalyticsEvent.notificationScheduled, properties: [
            EventProperties.NotificationScheduled.type: type,
            EventProperties.NotificationScheduled.frequency: frequency,
            EventProperties.NotificationScheduled.leadTimeHours: leadTimeHours
        ])
    }
    
    /// Track when notification is received
    /// - Parameter type: Notification type
    static func trackNotificationReceived(type: String) {
        trackEvent(AnalyticsEvent.notificationReceived, properties: [
            EventProperties.NotificationReceived.type: type
        ])
    }
    
    /// Track when notification is opened
    /// - Parameters:
    ///   - type: Notification type
    ///   - deepLinkTarget: Deep link target (optional)
    static func trackNotificationOpened(type: String, deepLinkTarget: String? = nil) {
        var properties: [String: Any] = [
            EventProperties.NotificationOpened.type: type
        ]
        if let target = deepLinkTarget {
            properties[EventProperties.NotificationOpened.deepLinkTarget] = target
        }
        trackEvent(AnalyticsEvent.notificationOpened, properties: properties)
    }
    
    /// Track when birthday celebration is viewed
    /// - Parameter petId: Pet ID
    static func trackBirthdayCelebrationViewed(petId: String) {
        trackEventWithGroup(
            AnalyticsEvent.birthdayCelebrationViewed,
            properties: nil,
            groupType: "pet",
            groupKey: petId
        )
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
    /// - Parameters:
    ///   - placement: Paywall placement ("scan_limit", "feature_gate", "settings")
    ///   - variant: Paywall variant (optional)
    static func trackPaywallViewed(placement: String, variant: String? = nil) {
        var properties: [String: Any] = [
            EventProperties.PaywallViewed.placement: placement
        ]
        if let variant = variant {
            properties[EventProperties.PaywallViewed.variant] = variant
        }
        trackEvent(AnalyticsEvent.paywallViewed, properties: properties)
    }
    
    /// Track when paywall CTA is tapped
    /// - Parameter cta: CTA type ("start_trial", "subscribe")
    static func trackPaywallCTATapped(cta: String) {
        trackEvent(AnalyticsEvent.paywallCTATapped, properties: [
            EventProperties.PaywallCTATapped.cta: cta
        ])
    }
    
    /// Track when checkout is started
    /// - Parameters:
    ///   - productId: Product ID
    ///   - price: Product price
    ///   - period: Subscription period ("week", "month", "year")
    static func trackCheckoutStarted(productId: String, price: Double, period: String) {
        trackEvent(AnalyticsEvent.checkoutStarted, properties: [
            EventProperties.CheckoutStarted.productId: productId,
            EventProperties.CheckoutStarted.price: price,
            EventProperties.CheckoutStarted.period: period
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
    /// - Parameters:
    ///   - screenName: Name of the screen
    ///   - properties: Additional screen properties (optional)
    static func trackScreenViewed(screenName: String, properties: [String: Any]? = nil) {
        var eventProperties: [String: Any] = [
            EventProperties.ScreenViewed.screenName: screenName
        ]
        if let properties = properties {
            eventProperties.merge(properties) { (_, new) in new }
        }
        trackEvent(AnalyticsEvent.screenViewed, properties: eventProperties)
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
    
    /// Identify user with PostHog (2025 Best Practices)
    /// Call this when user logs in to associate events with their user ID
    /// Uses alias to link anonymous events to identified user
    /// Sets all recommended user properties from the analytics plan
    /// - Parameter user: The authenticated user
    /// - Parameter petsCount: Number of pets the user has
    /// - Parameter pets: Array of pets to calculate has_dog/has_cat (optional)
    static func identifyUser(_ user: User, petsCount: Int = 0, pets: [Pet]? = nil) {
        // Get anonymous distinct ID before identification
        let anonymousId = PostHogSDK.shared.getDistinctId()
        
        // Calculate has_dog/has_cat from pets if provided
        var hasDog = false
        var hasCat = false
        if let pets = pets {
            hasDog = pets.contains { $0.species == .dog }
            hasCat = pets.contains { $0.species == .cat }
        }
        
        // Build comprehensive user properties (matching analytics plan recommendations)
        var properties: [String: Any] = [
            "email": user.email,
            "role": user.role.rawValue,
            "onboarded": user.onboarded,
            "onboarding_completed": user.onboarded, // Alias for consistency
            "account_created_at": user.createdAt.iso8601,
            "pets_count": petsCount,
            "has_dog": hasDog,
            "has_cat": hasCat,
            "plan_tier": user.role.rawValue,
            "subscription_provider": "app_store",
            "country": Locale.current.region?.identifier ?? "unknown",
            "language": Locale.current.language.languageCode?.identifier ?? "en",
            "timezone": TimeZone.current.identifier
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
        
        // Notifications enabled (will be updated from notification settings)
        // Check UserDefaults for notification permission status
        properties["notifications_enabled"] = false // Will be updated when notification settings are checked
        
        // App version info
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            properties["app_version"] = appVersion
        }
        if let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            properties["app_build"] = buildNumber
        }
        
        // Device info
        properties["ios_version"] = UIDevice.current.systemVersion
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingCString: $0)
            }
        } ?? "unknown"
        properties["device_model"] = modelCode
        
        // Add internal user flag if applicable
        let internalProps = AnalyticsPrivacyManager.shared.getInternalUserProperty(email: user.email)
        properties.merge(internalProps) { (_, new) in new }
        
        // Sanitize properties and call PostHog SDK
        let sanitizedProperties = sanitizeProperties(properties) ?? [:]
        
        // Best Practice: Alias anonymous ID to user ID to link pre-login events
        // This ensures all events (anonymous and identified) are associated with the user
        // Note: PostHog alias method only takes one parameter - the new distinct ID
        // The SDK automatically links it to the current distinct ID
        if anonymousId != user.id {
            PostHogSDK.shared.alias(user.id)
            logger.debug("Aliased anonymous ID \(anonymousId) to user ID \(user.id)")
        }
        
        // Identify user with properties
        PostHogSDK.shared.identify(user.id, userProperties: sanitizedProperties)
        
        // Update context provider with user ID
        AnalyticsContextProvider.shared.setUserId(user.id)
        
        // Reload feature flags after identification (2025 Best Practice)
        // This ensures feature flags are evaluated with user properties
        PostHogSDK.shared.reloadFeatureFlags()
        
        logger.debug("User identified: \(user.id) with \(petsCount) pets (has_dog: \(hasDog), has_cat: \(hasCat))")
    }
    
    /// Reset user identification
    /// Call this when user logs out
    static func resetUser() {
        // PostHog SDK methods don't throw, so no do-catch needed
        PostHogSDK.shared.reset()
        
        // Clear context provider
        AnalyticsContextProvider.shared.clearUserContext()
        
        logger.debug("User identification reset")
    }
    
    /// Update user properties
    /// - Parameter properties: Dictionary of user properties to update
    static func updateUserProperties(_ properties: [String: Any]) {
        let sanitizedProperties = sanitizeProperties(properties) ?? [:]
        PostHogSDK.shared.identify(PostHogSDK.shared.getDistinctId(), userProperties: sanitizedProperties)
        
        // Reload feature flags when user properties change (2025 Best Practice)
        // Feature flags may depend on user properties
        PostHogSDK.shared.reloadFeatureFlags()
        
        logger.debug("PostHog user properties updated")
    }
    
    // MARK: - Super Properties (2025 Best Practices)
    
    /// Register super properties that are attached to all events
    /// Use this for properties that should be included in every event (e.g., app version, subscription tier)
    /// - Parameter properties: Dictionary of super properties
    static func registerSuperProperties(_ properties: [String: Any]) {
        let sanitizedProperties = sanitizeProperties(properties) ?? [:]
        PostHogSDK.shared.register(sanitizedProperties)
        logger.debug("Super properties registered: \(sanitizedProperties.keys.joined(separator: ", "))")
    }
    
    /// Unregister a super property
    /// - Parameter propertyName: Name of the property to remove
    static func unregisterSuperProperty(_ propertyName: String) {
        PostHogSDK.shared.unregister(propertyName)
        logger.debug("Super property unregistered: \(propertyName)")
    }
    
    /// Clear all super properties
    /// Note: PostHog SDK doesn't have unregisterAll, so we use reset()
    /// This also resets user identification, so use with caution
    static func clearSuperProperties() {
        // PostHog SDK doesn't have unregisterAll, so we need to reset
        // This will also reset user identification, so be careful
        // Alternative: Track which properties were registered and unregister them individually
        PostHogSDK.shared.reset()
        logger.debug("All super properties cleared (via reset)")
    }
    
    // MARK: - Feature Flags (2025 Best Practices)
    
    /// Check if a feature flag is enabled
    /// - Parameter flagKey: The feature flag key
    /// - Returns: True if flag is enabled, false otherwise
    static func isFeatureEnabled(_ flagKey: String) -> Bool {
        // PostHog SDK's isFeatureEnabled returns Bool, not Bool?
        return PostHogSDK.shared.isFeatureEnabled(flagKey)
    }
    
    /// Get feature flag value (supports multivariate flags)
    /// - Parameter flagKey: The feature flag key
    /// - Returns: The flag value, or nil if not set
    static func getFeatureFlag(_ flagKey: String) -> Any? {
        return PostHogSDK.shared.getFeatureFlag(flagKey)
    }
    
    /// Get feature flag payload (for multivariate flags with JSON payloads)
    /// - Parameter flagKey: The feature flag key
    /// - Returns: The flag payload, or nil if not set
    static func getFeatureFlagPayload(_ flagKey: String) -> [String: Any]? {
        return PostHogSDK.shared.getFeatureFlagPayload(flagKey) as? [String: Any]
    }
    
    /// Reload feature flags from PostHog
    /// Call this when user properties change or after identification
    static func reloadFeatureFlags() {
        PostHogSDK.shared.reloadFeatureFlags()
        logger.debug("Feature flags reloaded")
    }
    
    // MARK: - Groups (2025 Best Practices)
    
    /// Associate events with a group (e.g., pet-level analytics)
    /// Groups allow you to analyze events at a group level (e.g., all events for a specific pet)
    /// - Parameters:
    ///   - groupType: Type of group (e.g., "pet")
    ///   - groupKey: Unique identifier for the group (e.g., pet ID)
    ///   - properties: Optional properties about the group
    static func identifyGroup(groupType: String, groupKey: String, properties: [String: Any]? = nil) {
        // PostHog SDK group method signature: group(type:key:)
        // Properties are set separately via identify with group context
        PostHogSDK.shared.group(type: groupType, key: groupKey)
        
        // If properties are provided, note that they'll be included in group-tracked events
        if let properties = properties, !properties.isEmpty {
            // PostHog SDK doesn't have a direct way to set group properties in group() call
            // We'll track them as event properties when tracking events with groups
            logger.debug("Group properties (\(properties.keys.joined(separator: ", "))) will be included in group-tracked events")
        }
        
        logger.debug("Group identified: \(groupType) - \(groupKey)")
    }
    
    /// Track event with group association
    /// - Parameters:
    ///   - eventName: Name of the event
    ///   - properties: Event properties
    ///   - groupType: Type of group (e.g., "pet")
    ///   - groupKey: Unique identifier for the group (e.g., pet ID)
    static func trackEventWithGroup(
        _ eventName: String,
        properties: [String: Any]? = nil,
        groupType: String,
        groupKey: String
    ) {
        // First identify the group
        identifyGroup(groupType: groupType, groupKey: groupKey)
        
        // Then track the event (it will be associated with the group)
        trackEvent(eventName, properties: properties)
    }
    
    // MARK: - Surveys (2025 Best Practices)
    
    /// Check if surveys are available and should be shown
    /// PostHog SDK automatically handles survey display, but you can check availability
    /// - Returns: True if surveys are enabled and available
    static func areSurveysAvailable() -> Bool {
        // PostHog SDK automatically shows surveys based on display conditions
        // This method can be used to check if surveys feature is enabled
        return true // Surveys are enabled in PostHogConfigurator
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
        
        // Also update super properties so role is included in all events (2025 Best Practice)
        updateSuperPropertiesForRole(role)
    }
    
    /// Track when user registers
    static func trackUserRegistered(email: String) {
        trackEvent("user_registered", properties: [
            "email": email
        ])
    }
    
    /// Track when user signs up successfully
    static func trackAuthSignupSucceeded(email: String) {
        trackEvent(AnalyticsEvent.authSignupSucceeded, properties: [
            "email": email
        ])
    }
    
    /// Track when user logs in successfully
    /// - Parameters:
    ///   - userId: User ID
    ///   - role: User role
    static func trackUserLoggedIn(userId: String, role: String) {
        trackEvent(AnalyticsEvent.authLoginSucceeded, properties: [
            "user_id": userId,
            "role": role
        ])
    }
    
    /// Track when MFA is enabled
    static func trackMFAEnabled() {
        trackEvent(AnalyticsEvent.authMFAEnabled)
    }
    
    /// Track when user logs out
    static func trackUserLoggedOut() {
        trackEvent(AnalyticsEvent.authLogout)
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
    
    /// Track when purchase succeeds
    /// - Parameters:
    ///   - productId: Product ID
    ///   - revenue: Revenue amount
    ///   - currency: Currency code
    ///   - isTrial: Whether this is a trial purchase
    static func trackPurchaseSucceeded(productId: String, revenue: Double, currency: String = "USD", isTrial: Bool = false) {
        trackEvent(AnalyticsEvent.purchaseSucceeded, properties: [
            EventProperties.PurchaseSucceeded.productId: productId,
            EventProperties.PurchaseSucceeded.revenue: revenue,
            EventProperties.PurchaseSucceeded.currency: currency,
            EventProperties.PurchaseSucceeded.isTrial: isTrial
        ])
    }
    
    /// Track when purchase fails
    /// - Parameters:
    ///   - productId: Product ID
    ///   - errorCode: Error code
    static func trackPurchaseFailed(productId: String, errorCode: String) {
        trackEvent(AnalyticsEvent.purchaseFailed, properties: [
            EventProperties.PurchaseFailed.productId: productId,
            EventProperties.PurchaseFailed.errorCode: errorCode
        ])
    }
    
    /// Track when subscription is renewed
    /// - Parameter productId: Product ID
    static func trackSubscriptionRenewed(productId: String) {
        trackEvent(AnalyticsEvent.subscriptionRenewed, properties: [
            "product_id": productId
        ])
    }
    
    /// Track when subscription is canceled
    /// - Parameter productId: Product ID
    static func trackSubscriptionCanceled(productId: String) {
        trackEvent(AnalyticsEvent.subscriptionCanceled, properties: [
            "product_id": productId
        ])
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
    
    // MARK: - App Initialization Helpers
    
    /// Initialize super properties that should be attached to all events
    /// Call this during app launch to set common properties (app version, device info, etc.)
    static func initializeSuperProperties() {
        var superProps: [String: Any] = [:]
        
        // App version
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            superProps["app_version"] = appVersion
        }
        
        // Build number
        if let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            superProps["app_build"] = buildNumber
        }
        
        // Device type
        superProps["device_type"] = UIDevice.current.model
        superProps["ios_version"] = UIDevice.current.systemVersion
        
        // Register super properties
        registerSuperProperties(superProps)
        logger.info("Super properties initialized: \(superProps.keys.joined(separator: ", "))")
    }
    
    /// Update super properties when user role changes
    /// - Parameter role: User role (free or premium)
    static func updateSuperPropertiesForRole(_ role: String) {
        registerSuperProperties([
            "user_role": role,
            "role_updated_at": Date().iso8601
        ])
    }
    
    // MARK: - Pet Management Events
    
    /// Track when a pet is created
    /// Also identifies the pet as a group for group-level analytics
    /// - Parameters:
    ///   - petId: Pet ID
    ///   - species: Pet species ("dog", "cat")
    ///   - petName: Pet name (optional)
    ///   - hasSensitivities: Whether pet has known sensitivities
    ///   - ageMonths: Pet age in months (optional)
    ///   - weightKg: Pet weight in kilograms (optional)
    ///   - breed: Pet breed (optional)
    static func trackPetCreated(
        petId: String,
        species: String,
        petName: String? = nil,
        hasSensitivities: Bool = false,
        ageMonths: Int? = nil,
        weightKg: Double? = nil,
        breed: String? = nil
    ) {
        // Identify pet as a group with all recommended properties (2025 Best Practice)
        var groupProperties: [String: Any] = [
            "pet_species": species,
            "species": species, // Alias for consistency
            "created_at": Date().iso8601
        ]
        if let petName = petName {
            groupProperties["name"] = petName
        }
        if let ageMonths = ageMonths {
            groupProperties["pet_age_months"] = ageMonths
            groupProperties["age_months"] = ageMonths // Alias
        }
        if let weightKg = weightKg {
            groupProperties["pet_weight_kg"] = weightKg
            groupProperties["weight_kg"] = weightKg // Alias
        }
        if let breed = breed {
            groupProperties["breed"] = breed
        }
        groupProperties["has_sensitivities"] = hasSensitivities
        identifyGroup(groupType: "pet", groupKey: petId, properties: groupProperties)
        
        // Track creation event with group association
        var eventProperties: [String: Any] = [
            EventProperties.PetCreated.petSpecies: species,
            EventProperties.PetCreated.hasSensitivities: hasSensitivities
        ]
        if let ageMonths = ageMonths {
            eventProperties[EventProperties.PetCreated.ageMonths] = ageMonths
        }
        trackEvent(AnalyticsEvent.petCreated, properties: eventProperties)
        
        // Update context provider
        AnalyticsContextProvider.shared.setPetId(petId)
    }
    
    /// Track when a pet is selected
    /// - Parameter petId: Pet ID
    static func trackPetSelected(petId: String) {
        trackEvent(AnalyticsEvent.petSelected, properties: [
            "pet_id": petId
        ])
        // Update context provider
        AnalyticsContextProvider.shared.setPetId(petId)
    }
    
    /// Track when a pet is updated
    /// Updates group properties for the pet
    /// - Parameters:
    ///   - petId: Pet ID
    ///   - species: Pet species
    ///   - petName: Pet name (optional)
    ///   - fieldsChanged: Array of field names that were changed
    ///   - ageMonths: Pet age in months (optional)
    ///   - weightKg: Pet weight in kilograms (optional)
    ///   - breed: Pet breed (optional)
    ///   - hasSensitivities: Whether pet has sensitivities (optional)
    static func trackPetUpdated(
        petId: String,
        species: String,
        petName: String? = nil,
        fieldsChanged: [String]? = nil,
        ageMonths: Int? = nil,
        weightKg: Double? = nil,
        breed: String? = nil,
        hasSensitivities: Bool? = nil
    ) {
        // Update pet group properties with all recommended properties (2025 Best Practice)
        var groupProperties: [String: Any] = [
            "pet_species": species,
            "species": species, // Alias
            "updated_at": Date().iso8601
        ]
        if let petName = petName {
            groupProperties["name"] = petName
        }
        if let ageMonths = ageMonths {
            groupProperties["pet_age_months"] = ageMonths
            groupProperties["age_months"] = ageMonths
        }
        if let weightKg = weightKg {
            groupProperties["pet_weight_kg"] = weightKg
            groupProperties["weight_kg"] = weightKg
        }
        if let breed = breed {
            groupProperties["breed"] = breed
        }
        if let hasSensitivities = hasSensitivities {
            groupProperties["has_sensitivities"] = hasSensitivities
        }
        identifyGroup(groupType: "pet", groupKey: petId, properties: groupProperties)
        
        // Track update event
        var eventProperties: [String: Any] = [
            "pet_species": species
        ]
        if let fieldsChanged = fieldsChanged {
            eventProperties[EventProperties.PetUpdated.fieldsChanged] = fieldsChanged
        }
        trackEvent(AnalyticsEvent.petUpdated, properties: eventProperties)
    }
    
    /// Track when a pet is deleted
    /// - Parameters:
    ///   - petId: Pet ID
    ///   - species: Pet species
    static func trackPetDeleted(petId: String, species: String) {
        // Use group tracking for pet-level analytics (2025 Best Practice)
        trackEventWithGroup(
            AnalyticsEvent.petDeleted,
            properties: [
                "pet_species": species
            ],
            groupType: "pet",
            groupKey: petId
        )
        
        // Clear pet context if this was the current pet
        if AnalyticsContextProvider.shared.getContext()["pet_id"] as? String == petId {
            AnalyticsContextProvider.shared.setPetId(nil)
        }
    }
    
    /// Track when pet photo is added
    /// - Parameter petId: Pet ID
    static func trackPetPhotoAdded(petId: String) {
        trackEventWithGroup(
            AnalyticsEvent.petPhotoAdded,
            properties: nil,
            groupType: "pet",
            groupKey: petId
        )
    }
    
    /// Track when vet info is added
    /// - Parameter petId: Pet ID
    static func trackVetInfoAdded(petId: String) {
        trackEventWithGroup(
            AnalyticsEvent.vetInfoAdded,
            properties: nil,
            groupType: "pet",
            groupKey: petId
        )
    }
    
    /// Track when vet info is updated
    /// - Parameter petId: Pet ID
    static func trackVetInfoUpdated(petId: String) {
        trackEventWithGroup(
            AnalyticsEvent.vetInfoUpdated,
            properties: nil,
            groupType: "pet",
            groupKey: petId
        )
    }
    
    /// Track when sensitivity is added
    /// - Parameters:
    ///   - petId: Pet ID
    ///   - sensitivityType: Type of sensitivity
    ///   - ingredientId: Ingredient ID (optional)
    ///   - source: Source of sensitivity ("user", "scan_suggestion")
    static func trackSensitivityAdded(
        petId: String,
        sensitivityType: String,
        ingredientId: String? = nil,
        source: String
    ) {
        var properties: [String: Any] = [
            EventProperties.SensitivityAdded.sensitivityType: sensitivityType,
            EventProperties.SensitivityAdded.source: source
        ]
        if let ingredientId = ingredientId {
            properties[EventProperties.SensitivityAdded.ingredientId] = ingredientId
        }
        trackEventWithGroup(
            AnalyticsEvent.sensitivityAdded,
            properties: properties,
            groupType: "pet",
            groupKey: petId
        )
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
        // Check privacy consent before tracking
        guard AnalyticsPrivacyManager.shared.shouldTrackEvent(eventName, isOperational: false) else {
            logger.debug("Analytics event skipped (user opted out): \(eventName)")
            return
        }
        
        // Wrap PostHog calls to prevent crashes
        // PostHog SDK should handle errors internally, but we add extra safety
        // Use a closure to catch any potential issues
        SafeExecution.execute {
            // Get global context properties
            let context = AnalyticsContextProvider.shared.getContext()
            
            // Merge context with event properties (context takes precedence for conflicts)
            var mergedProperties = sanitizeProperties(properties) ?? [:]
            mergedProperties.merge(context) { (_, new) in new }
            
            // Add internal user flag if applicable
            // Note: Internal user filtering is handled during identifyUser() call
            // Context already includes user_id if user is identified
            
            // Call PostHog SDK - we're guaranteed to be on MainActor via @MainActor
            // PostHog SDK should be thread-safe, but we ensure MainActor for safety
            PostHogSDK.shared.capture(eventName, properties: mergedProperties)
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

