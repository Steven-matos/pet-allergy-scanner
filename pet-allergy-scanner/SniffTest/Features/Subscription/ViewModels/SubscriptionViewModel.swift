//
//  SubscriptionViewModel.swift
//  SniffTest
//
//  View model for managing subscription UI state and interactions
//

import Foundation
import SwiftUI
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
    
    private let storeKitService: StoreKitService
    private let authService: AuthService
    private let logger = Logger(subsystem: "com.snifftest.app", category: "Subscription")
    
    // MARK: - Computed Properties
    
    var products: [SubscriptionProduct] {
        storeKitService.products
    }
    
    var isLoading: Bool {
        storeKitService.isLoading
    }
    
    var hasActiveSubscription: Bool {
        storeKitService.hasActiveSubscription
    }
    
    var subscriptionStatus: SubscriptionStatus {
        storeKitService.subscriptionStatus
    }
    
    var isPremiumUser: Bool {
        authService.currentUser?.role == .premium
    }
    
    var expirationDateText: String? {
        storeKitService.formattedExpirationDate
    }
    
    // MARK: - Initialization
    
    init(
        storeKitService: StoreKitService = .shared,
        authService: AuthService = .shared
    ) {
        self.storeKitService = storeKitService
        self.authService = authService
        
        // Select yearly subscription by default (best value)
        if let yearlyProduct = storeKitService.products.first(where: { 
            $0.id == SubscriptionProductID.yearly.rawValue 
        }) {
            self.selectedProductID = yearlyProduct.id
        } else if let monthlyProduct = storeKitService.products.first(where: {
            $0.id == SubscriptionProductID.monthly.rawValue
        }) {
            self.selectedProductID = monthlyProduct.id
        }
    }
    
    // MARK: - Actions
    
    /// Purchase the selected subscription
    func purchaseSubscription() async {
        guard let selectedProductID = selectedProductID,
              let product = products.first(where: { $0.id == selectedProductID }) else {
            showError("Please select a subscription plan")
            return
        }
        
        logger.info("Starting purchase for product: \(selectedProductID)")
        
        let result = await storeKitService.purchase(product)
        
        switch result {
        case .success:
            showPurchaseSuccess()
            await syncSubscriptionWithBackend()
            
        case .userCancelled:
            logger.info("User cancelled purchase")
            
        case .pending:
            showError("Your purchase is pending. Please check back later.")
            
        case .failed(let error):
            showError("Purchase failed: \(error.localizedDescription)")
        }
    }
    
    /// Restore previous purchases
    func restorePurchases() async {
        logger.info("Restoring purchases")
        
        await storeKitService.restorePurchases()
        
        if storeKitService.hasActiveSubscription {
            showRestoreSuccess()
            await syncSubscriptionWithBackend()
        } else {
            showError("No previous purchases found")
        }
    }
    
    /// Refresh subscription status
    func refreshStatus() async {
        await storeKitService.updateSubscriptionStatus()
    }
    
    /// Open subscription management in Settings
    func manageSubscription() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Private Methods
    
    /// Sync subscription status with backend
    private func syncSubscriptionWithBackend() async {
        // TODO: Implement backend sync to update user role to premium
        // This should call your API to update the user's subscription status
        logger.info("Syncing subscription status with backend")
        
        // In production, you should verify the receipt with your backend
        // and update the user's subscription status accordingly
        // Example: await authService.updateUserRole(.premium)
        
        // For now, log that subscription is active
        if storeKitService.hasActiveSubscription {
            logger.info("User has active subscription - backend sync needed")
        }
    }
    
    /// Show purchase success alert
    private func showPurchaseSuccess() {
        alertMessage = "Welcome to Premium! 🎉\nYou now have access to all premium features."
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

