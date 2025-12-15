//
//  EventSchema.swift
//  SniffTest
//
//  Typed event schemas matching PostHog Analytics Implementation Plan taxonomy
//  Prevents typos and ensures consistent event naming across the app
//

import Foundation

// MARK: - Event Name Constants

/// Typed event names following snake_case convention
/// All event names are defined here to prevent typos and ensure consistency
enum AnalyticsEvent {
    // MARK: - Lifecycle Events
    
    static let appInstalled = "app_installed"
    static let appOpened = "app_opened"
    static let appBackgrounded = "app_backgrounded"
    static let appForegrounded = "app_foregrounded"
    static let appCrashed = "app_crashed"
    
    // MARK: - Onboarding & Authentication
    
    static let onboardingStarted = "onboarding_started"
    static let onboardingStepViewed = "onboarding_step_viewed"
    static let onboardingCompleted = "onboarding_completed"
    static let authSignupSucceeded = "auth_signup_succeeded"
    static let authLoginSucceeded = "auth_login_succeeded"
    static let authMFAEnabled = "auth_mfa_enabled"
    static let authLogout = "auth_logout"
    
    // MARK: - Pet Management
    
    static let petCreated = "pet_created"
    static let petUpdated = "pet_updated"
    static let petDeleted = "pet_deleted"
    static let petSelected = "pet_selected"
    static let petPhotoAdded = "pet_photo_added"
    static let vetInfoAdded = "vet_info_added"
    static let vetInfoUpdated = "vet_info_updated"
    static let sensitivityAdded = "sensitivity_added"
    
    // MARK: - Scanning Funnel (Critical Path)
    
    static let scanStarted = "scan_started"
    static let scanPermissionPrompted = "scan_permission_prompted"
    static let scanPermissionResult = "scan_permission_result"
    static let scanCaptureSucceeded = "scan_capture_succeeded"
    static let ocrExtracted = "ocr_extracted"
    static let barcodeDetected = "barcode_detected"
    static let analysisRequested = "analysis_requested"
    static let analysisSucceeded = "analysis_succeeded"
    static let analysisFailed = "analysis_failed"
    static let scanCompleted = "scan_completed"
    static let reportViewed = "report_viewed"
    static let reportShared = "report_shared"
    static let reportSavedToHistory = "report_saved_to_history"
    static let favoriteAdded = "favorite_added"
    static let favoriteRemoved = "favorite_removed"
    static let scanRescanned = "scan_rescanned"
    static let scanEdited = "scan_edited"
    static let foodDatabaseLookup = "food_database_lookup"
    
    // MARK: - Nutrition & Feeding
    
    static let nutritionDashboardViewed = "nutrition_dashboard_viewed"
    static let feedingLogAdded = "feeding_log_added"
    static let feedingLogEdited = "feeding_log_edited"
    static let feedingLogDeleted = "feeding_log_deleted"
    static let calorieGoalSet = "calorie_goal_set"
    static let weightRecordAdded = "weight_record_added"
    static let weightGoalSet = "weight_goal_set"
    static let foodCompared = "food_compared"
    static let nutritionInsightViewed = "nutrition_insight_viewed"
    
    // MARK: - Notifications
    
    static let pushPermissionPrompted = "push_permission_prompted"
    static let pushPermissionResult = "push_permission_result"
    static let notificationScheduled = "notification_scheduled"
    static let notificationReceived = "notification_received"
    static let notificationOpened = "notification_opened"
    static let birthdayCelebrationViewed = "birthday_celebration_viewed"
    
    // MARK: - Subscription & Paywall
    
    static let paywallViewed = "paywall_viewed"
    static let paywallCTATapped = "paywall_cta_tapped"
    static let checkoutStarted = "checkout_started"
    static let purchaseSucceeded = "purchase_succeeded"
    static let purchaseFailed = "purchase_failed"
    static let subscriptionRenewed = "subscription_renewed"
    static let subscriptionCanceled = "subscription_canceled"
    
    // MARK: - Screen Tracking
    
    static let screenViewed = "screen_viewed"
}

// MARK: - Event Property Schemas

/// Property schemas for each event type
/// Documents required/optional properties and PII rules
struct EventProperties {
    
    // MARK: - Lifecycle Properties
    
    struct AppOpened {
        static let isFirstLaunch = "is_first_launch"
        static let timeSinceLastLaunch = "time_since_last_launch_seconds"
    }
    
    // MARK: - Onboarding Properties
    
    struct OnboardingStepViewed {
        static let step = "step" // "welcome" | "add_pet" | "permissions" | "first_scan_prompt"
    }
    
    struct OnboardingCompleted {
        static let timeToCompleteSec = "time_to_complete_sec"
        static let petsCount = "pets_count"
    }
    
    // MARK: - Pet Properties
    
    struct PetCreated {
        static let petSpecies = "pet_species" // "dog" | "cat"
        static let hasSensitivities = "has_sensitivities"
        static let ageMonths = "age_months"
    }
    
    struct PetUpdated {
        static let fieldsChanged = "fields_changed" // Array of field names
    }
    
    struct SensitivityAdded {
        static let sensitivityType = "sensitivity_type"
        static let ingredientId = "ingredient_id" // Optional
        static let source = "source" // "user" | "scan_suggestion"
    }
    
    // MARK: - Scanning Properties
    
    struct ScanStarted {
        static let mode = "mode" // "camera" | "photo" | "barcode"
    }
    
    struct ScanPermissionPrompted {
        static let permission = "permission" // "camera" | "photos"
    }
    
    struct ScanPermissionResult {
        static let permission = "permission"
        static let status = "status" // "granted" | "denied" | "limited"
    }
    
    struct ScanCaptureSucceeded {
        static let mode = "mode"
        static let imageSource = "image_source" // "camera" | "library"
    }
    
    struct OCRExtracted {
        static let textLength = "text_length"
        static let confidenceAvg = "confidence_avg" // Optional
    }
    
    struct BarcodeDetected {
        static let barcodeType = "barcode_type"
        static let barcodePresent = "barcode_present"
    }
    
    struct AnalysisRequested {
        static let analysisType = "analysis_type" // "ingredients" | "nutrition" | "both"
    }
    
    struct AnalysisSucceeded {
        static let unsafeIngredientCount = "unsafe_ingredient_count"
        static let allergenMatchCount = "allergen_match_count"
        static let species = "species" // "dog" | "cat"
        static let hasRecommendations = "has_recommendations"
    }
    
    struct AnalysisFailed {
        static let stage = "stage" // "ocr" | "barcode" | "backend" | "parsing"
        static let errorCode = "error_code"
        static let errorDomain = "error_domain"
    }
    
    struct ScanCompleted {
        static let status = "status" // "success" | "partial" | "failed"
        static let durationMsTotal = "duration_ms_total"
        static let durationMsOCR = "duration_ms_ocr"
        static let durationMsBackend = "duration_ms_backend"
    }
    
    struct ReportViewed {
        static let reportType = "report_type" // "safety" | "nutrition"
        static let unsafeIngredientCount = "unsafe_ingredient_count"
    }
    
    struct ReportShared {
        static let method = "method" // "system_share" | "copy_link"
    }
    
    struct ScanRescanned {
        static let reason = "reason" // "blurry" | "missing_ingredients" | "wrong_product"
    }
    
    struct ScanEdited {
        static let editType = "edit_type" // "ingredients_text" | "product_name"
    }
    
    struct FoodDatabaseLookup {
        static let method = "method" // "barcode" | "search"
        static let hit = "hit" // bool
    }
    
    // MARK: - Nutrition Properties
    
    struct FeedingLogAdded {
        static let mealType = "meal_type" // "breakfast" | "lunch" | "dinner" | "snack"
        static let calories = "calories"
        static let portionGrams = "portion_grams"
    }
    
    struct CalorieGoalSet {
        static let goalCaloriesDaily = "goal_calories_daily"
        static let source = "source" // "recommendation" | "manual"
    }
    
    struct WeightRecordAdded {
        static let weightKg = "weight_kg"
        static let source = "source" // "manual" | "vet"
    }
    
    struct WeightGoalSet {
        static let targetWeightKg = "target_weight_kg"
        static let timeHorizonDays = "time_horizon_days"
    }
    
    struct FoodCompared {
        static let itemsCount = "items_count"
    }
    
    // MARK: - Notification Properties
    
    struct PushPermissionResult {
        static let status = "status" // "granted" | "denied"
    }
    
    struct NotificationScheduled {
        static let type = "type" // "birthday" | "medication"
        static let frequency = "frequency"
        static let leadTimeHours = "lead_time_hours"
    }
    
    struct NotificationReceived {
        static let type = "type"
    }
    
    struct NotificationOpened {
        static let type = "type"
        static let deepLinkTarget = "deep_link_target"
    }
    
    // MARK: - Subscription Properties
    
    struct PaywallViewed {
        static let placement = "placement" // "scan_limit" | "feature_gate" | "settings"
        static let variant = "variant" // Optional
    }
    
    struct PaywallCTATapped {
        static let cta = "cta" // "start_trial" | "subscribe"
    }
    
    struct CheckoutStarted {
        static let productId = "product_id"
        static let price = "price"
        static let period = "period" // "week" | "month" | "year"
    }
    
    struct PurchaseSucceeded {
        static let productId = "product_id"
        static let revenue = "revenue"
        static let currency = "currency"
        static let isTrial = "is_trial"
    }
    
    struct PurchaseFailed {
        static let productId = "product_id"
        static let errorCode = "error_code"
    }
    
    // MARK: - Screen Properties
    
    struct ScreenViewed {
        static let screenName = "screen_name"
    }
}

// MARK: - PII Rules Documentation

/**
 * PII (Personally Identifiable Information) Rules
 * 
 * DO NOT send to PostHog:
 * - Raw OCR text
 * - Ingredient text (full ingredient lists)
 * - Vet notes (free-form text)
 * - Email addresses (redact in beforeSend hook)
 * - Phone numbers (redact in beforeSend hook)
 * - Any free-form user input
 * 
 * DO send (summaries/counts only):
 * - Ingredient count
 * - Unsafe ingredient count
 * - Allergen match count
 * - OCR confidence aggregates
 * - Error codes/domains (not full error messages)
 * 
 * Privacy controls are enforced in:
 * - PostHogConfigurator.setBeforeSend() hook
 * - AnalyticsPrivacyManager
 */
