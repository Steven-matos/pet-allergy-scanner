//
//  SubscriptionTier.swift
//  SniffTest
//
//  Defines subscription tiers and feature limits for free and premium users
//

import Foundation

/// Subscription tier limits and features
enum SubscriptionTier {
    case free
    case premium
    
    /// Maximum number of scans allowed per day
    var dailyScanLimit: Int {
        switch self {
        case .free:
            return 5
        case .premium:
            return .max // Unlimited
        }
    }
    
    /// Maximum number of pets allowed
    var maxPets: Int {
        switch self {
        case .free:
            return 1
        case .premium:
            return .max // Unlimited
        }
    }
    
    /// Maximum number of scans to keep in history
    var scanHistoryLimit: Int? {
        switch self {
        case .free:
            return 5 // Only last 5 scans
        case .premium:
            return nil // Unlimited history
        }
    }
    
    /// Whether user has access to health tracking and insights
    var hasHealthTracking: Bool {
        switch self {
        case .free:
            return false
        case .premium:
            return true
        }
    }
    
    /// Whether user has access to detailed analytics
    var hasDetailedAnalytics: Bool {
        switch self {
        case .free:
            return false
        case .premium:
            return true
        }
    }
    
    /// Whether user has access to trends
    var hasTrends: Bool {
        switch self {
        case .free:
            return false
        case .premium:
            return true
        }
    }
    
    /// Display name for the tier
    var displayName: String {
        switch self {
        case .free:
            return "Free"
        case .premium:
            return "Premium"
        }
    }
}

/// Service for checking subscription limits and gating features
@MainActor
class SubscriptionGatekeeper: ObservableObject {
    static let shared = SubscriptionGatekeeper()
    
    @Published var showingUpgradePrompt = false
    @Published var upgradePromptMessage = ""
    @Published var upgradePromptTitle = ""
    
    private let subscriptionProvider = RevenueCatSubscriptionProvider.shared
    
    private init() {}
    
    /// Get the current user's subscription tier
    var currentTier: SubscriptionTier {
        subscriptionProvider.hasActiveSubscription ? .premium : .free
    }
    
    /// Check if user can perform a scan
    /// - Parameter currentDailyScans: Number of scans already performed today
    /// - Returns: True if scan is allowed, false if limit reached
    func canPerformScan(currentDailyScans: Int) -> Bool {
        let tier = currentTier
        
        guard tier == .free else {
            return true // Premium users have unlimited scans
        }
        
        return currentDailyScans < tier.dailyScanLimit
    }
    
    /// Show soft gate prompt when scan limit is reached
    func showScanLimitPrompt() {
        upgradePromptTitle = "Daily Scan Limit Reached"
        upgradePromptMessage = "You've reached your 5 free scans today! 🐾\n\nUnlock unlimited scans and deeper insights with SniffTest Premium."
        showingUpgradePrompt = true
    }
    
    /// Check if user can add another pet
    /// - Parameter currentPetCount: Number of pets user already has
    /// - Returns: True if pet can be added, false if limit reached
    func canAddPet(currentPetCount: Int) -> Bool {
        let tier = currentTier
        return currentPetCount < tier.maxPets
    }
    
    /// Show soft gate prompt when pet limit is reached
    func showPetLimitPrompt() {
        upgradePromptTitle = "Upgrade to Add More Pets"
        upgradePromptMessage = "Free users can have 1 pet profile. 🐕\n\nUpgrade to Premium to manage unlimited pets and their health data!"
        showingUpgradePrompt = true
    }
    
    /// Check if user can access health tracking features
    /// - Returns: True if user has premium, false otherwise
    func canAccessHealthTracking() -> Bool {
        currentTier.hasHealthTracking
    }
    
    /// Show soft gate prompt for health tracking
    func showHealthTrackingPrompt() {
        upgradePromptTitle = "Premium Feature"
        upgradePromptMessage = "Health tracking and insights are available with SniffTest Premium. 📊\n\nGet detailed analytics, weight tracking, and personalized recommendations!"
        showingUpgradePrompt = true
    }
    
    /// Check if user can access detailed analytics
    /// - Returns: True if user has premium, false otherwise
    func canAccessAnalytics() -> Bool {
        currentTier.hasDetailedAnalytics
    }
    
    /// Show soft gate prompt for analytics
    func showAnalyticsPrompt() {
        upgradePromptTitle = "Premium Feature"
        upgradePromptMessage = "Detailed analytics are available with SniffTest Premium. 📈\n\nTrack your pet's nutrition over time and get actionable insights!"
        showingUpgradePrompt = true
    }
    
    /// Check if user can access trends
    /// - Returns: True if user has premium, false otherwise
    func canAccessTrends() -> Bool {
        currentTier.hasTrends
    }
    
    /// Show soft gate prompt for trends
    func showTrendsPrompt() {
        upgradePromptTitle = "Premium Feature"
        upgradePromptMessage = "Nutrition trends are available with SniffTest Premium. 📉\n\nSee how your pet's diet changes over time!"
        showingUpgradePrompt = true
    }
    
    /// Get scan history limit for current tier
    /// - Returns: Maximum number of scans to show in history, or nil for unlimited
    func getScanHistoryLimit() -> Int? {
        currentTier.scanHistoryLimit
    }
    
    /// Get remaining scans for today
    /// - Parameter currentDailyScans: Number of scans already performed today
    /// - Returns: Number of scans remaining, or nil for unlimited
    func getRemainingDailyScans(currentDailyScans: Int) -> Int? {
        guard currentTier == .free else {
            return nil // Premium has unlimited
        }
        
        let remaining = currentTier.dailyScanLimit - currentDailyScans
        return max(0, remaining)
    }
}

