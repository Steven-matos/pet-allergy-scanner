//
//  SubscriptionViewModel.swift
//  SniffTest
//
//  View model for managing subscription UI state and interactions
//

import Foundation
import SwiftUI
import Combine
import os.log

/// View model for subscription management
@MainActor
final class SubscriptionViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var selectedProductID: String?
    @Published var showingPurchaseSuccess = false
    @Published var showingRestoreSuccess = false
    @Published var showingError = false
    @Published var alertMessage = ""
    
    // MARK: - Dependencies
    
    private let subscriptionProvider: any SubscriptionProviding
    private let authService: AuthService
    private let logger = Logger(subsystem: "com.snifftest.app", category: "Subscription")
    private var cancellables: Set<AnyCancellable> = []
    
    // MARK: - Computed Properties
    
    var products: [SubscriptionProduct] {
        subscriptionProvider.products
    }
    
    var isLoading: Bool {
        subscriptionProvider.isLoading
    }
    
    var hasActiveSubscription: Bool {
        subscriptionProvider.hasActiveSubscription
    }
    
    var subscriptionStatus: SubscriptionStatus {
        subscriptionProvider.subscriptionStatus
    }
    
    var isPremiumUser: Bool {
        authService.currentUser?.role == .premium
    }
    
    var expirationDateText: String? {
        subscriptionProvider.formattedExpirationDate
    }
    
    // MARK: - Initialization
    
    init(
        subscriptionProvider: any SubscriptionProviding = RevenueCatSubscriptionProvider.shared,
        authService: AuthService = .shared
    ) {
        self.subscriptionProvider = subscriptionProvider
        self.authService = authService
        observeProviderChanges()
        selectDefaultProductIfNeeded()
    }
    
    // MARK: - Actions
    
    /// Purchase the selected subscription
    func purchaseSubscription() async {
        guard let selectedProductID = selectedProductID,
              let product = products.first(where: { $0.id == selectedProductID }) else {
            showError("Please select a subscription plan")
            return
        }
        
        
        let result = await subscriptionProvider.purchase(product)
        
        switch result {
        case .success:
            showPurchaseSuccess()
            // Give RevenueCat a moment to update internal state after purchase
            // The subscription provider's applyCustomerInfo() will also sync via delegate
            // We sync here as a secondary check after ensuring status is updated
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            await syncSubscriptionWithBackend()
            
        case .userCancelled:
            // User cancelled purchase - no action needed
            break
            
        case .pending:
            showError("Your purchase is pending. Please check back later.")
            
        case .failed(let error):
            showError("Purchase failed: \(error.localizedDescription)")
        }
    }
    
    /// Restore previous purchases
    func restorePurchases() async {
        
        await subscriptionProvider.restorePurchases()
        
        if subscriptionProvider.hasActiveSubscription {
            showRestoreSuccess()
            await syncSubscriptionWithBackend()
        } else {
            showError("No previous purchases found")
        }
    }
    
    /// Refresh subscription status
    func refreshStatus() async {
        if products.isEmpty {
            await subscriptionProvider.refreshOfferings()
            selectDefaultProductIfNeeded()
        }
        await subscriptionProvider.refreshCustomerInfo()
    }
    
    /// Open subscription management in Settings
    func manageSubscription() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Private Methods
    
    /// Sync subscription status with backend
    /// The backend will be updated via RevenueCat webhooks, but this provides a secondary check
    private func syncSubscriptionWithBackend() async {
        
        guard subscriptionProvider.hasActiveSubscription else {
            return
        }
        
        do {
            // Call the subscription status endpoint to trigger backend verification
            // The backend will check RevenueCat's API and update the user's role if needed
            let apiService = APIService.shared
            let response = try await apiService.get(
                endpoint: "/subscriptions/status",
                responseType: SubscriptionStatusResponse.self
            )
            
            
            // Refresh user profile to get updated role from backend
            // Force refresh to bypass cache and get latest role from server
            // Refresh for both active subscriptions AND bypass users (is_premium = true)
            if response.hasSubscription || response.isPremium {
                await authService.refreshUserProfile(forceRefresh: true)
            }
        } catch {
            logger.error("Failed to sync subscription with backend: \(error.localizedDescription)")
            // Don't show error to user - this is a background sync operation
        }
    }
    
    /// Response model for subscription status endpoint
    private struct SubscriptionStatusResponse: Codable {
        let hasSubscription: Bool
        let isPremium: Bool
        let bypassSubscription: Bool?
        let status: String?
        let expiresAt: Date?
        let productId: String?
        
        enum CodingKeys: String, CodingKey {
            case hasSubscription = "has_subscription"
            case isPremium = "is_premium"
            case bypassSubscription = "bypass_subscription"
            case status
            case expiresAt = "expires_at"
            case productId = "product_id"
        }
    }
    
    /// Show purchase success alert
    private func showPurchaseSuccess() {
        alertMessage = "Welcome to Premium! 🎉\n\nYou now have:\n• Unlimited daily scans\n• Unlimited pets\n• Health tracking & analytics\n• Nutrition trends"
        showingPurchaseSuccess = true
        HapticFeedback.success()
    }
    
    /// Show restore success alert
    private func showRestoreSuccess() {
        alertMessage = "Purchases restored successfully! ✓"
        showingRestoreSuccess = true
        HapticFeedback.success()
    }
    
    /// Show error alert
    private func showError(_ message: String) {
        alertMessage = message
        showingError = true
        HapticFeedback.error()
        logger.error("Error: \(message)")
    }
    
    // MARK: - Helper Methods
    
    /// Get savings text for a product compared to weekly
    /// - Parameter product: The product to check
    /// - Returns: Savings text or nil
    func savings(for product: SubscriptionProduct) -> String? {
        // Calculate savings compared to weekly rate
        guard let weeklyProduct = products.first(where: { 
            $0.id == SubscriptionProductID.weekly.rawValue 
        }) else {
            return product.savings(comparedTo: products.first ?? product)
        }
        
        return product.savings(comparedTo: weeklyProduct)
    }
    
    /// Check if a product is selected
    /// - Parameter product: The product to check
    /// - Returns: True if selected
    func isSelected(_ product: SubscriptionProduct) -> Bool {
        selectedProductID == product.id
    }
    
    /// Select a product
    /// - Parameter product: The product to select
    func selectProduct(_ product: SubscriptionProduct) {
        selectedProductID = product.id
        HapticFeedback.light()
    }
}

// MARK: - Provider Observation

private extension SubscriptionViewModel {
    /// Observe the subscription provider so view model publishes updates when underlying state changes.
    func observeProviderChanges() {
        // The view model will manually refresh when needed
        // Provider state is accessed directly via computed properties
    }
    
    /// Select the default product if nothing is currently chosen.
    func selectDefaultProductIfNeeded() {
        guard selectedProductID == nil else { return }
        if let yearly = products.first(where: { $0.id == SubscriptionProductID.yearly.rawValue }) {
            selectedProductID = yearly.id
            return
        }
        if let monthly = products.first(where: { $0.id == SubscriptionProductID.monthly.rawValue }) {
            selectedProductID = monthly.id
            return
        }
        if let first = products.first {
            selectedProductID = first.id
        }
    }
}

