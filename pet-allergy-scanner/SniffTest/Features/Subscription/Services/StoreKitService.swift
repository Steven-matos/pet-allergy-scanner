//
//  StoreKitService.swift
//  SniffTest
//
//  Service for managing StoreKit 2 subscriptions and purchases
//

import Foundation
import StoreKit
import os.log

/// Service class responsible for managing in-app purchases and subscriptions
@MainActor
final class StoreKitService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var products: [SubscriptionProduct] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var subscriptionStatus: SubscriptionStatus = .notSubscribed
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.snifftest.app", category: "StoreKit")
    private var updateListenerTask: Task<Void, Error>?
    
    // MARK: - Singleton
    
    static let shared = StoreKitService()
    
    private init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Product Loading
    
    /// Load available subscription products from App Store
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let productIDs = SubscriptionProductID.allCases.map { $0.rawValue }
            let storeProducts = try await Product.products(for: productIDs)
            
            products = storeProducts.map { product in
                SubscriptionProduct(id: product.id, product: product)
            }
            
            // Sort products by price (lowest first)
            products.sort { $0.product.price < $1.product.price }
            
            logger.info("Loaded \(self.products.count) products")
        } catch {
            logger.error("Failed to load products: \(error.localizedDescription)")
            errorMessage = "Failed to load subscription options. Please try again."
        }
        
        isLoading = false
    }
    
    // MARK: - Purchase Management
    
    /// Purchase a subscription product
    /// - Parameter product: The subscription product to purchase
    /// - Returns: Result of the purchase operation
    func purchase(_ product: SubscriptionProduct) async -> PurchaseResult {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let result = try await product.product.purchase()
            
            switch result {
            case .success(let verificationResult):
                let transaction = try await checkVerified(verificationResult)
                
                // Update subscription status
                await updateSubscriptionStatus()
                
                // Finish the transaction
                await transaction.finish()
                
                logger.info("Purchase successful: \(product.id)")
                return .success
                
            case .userCancelled:
                logger.info("User cancelled purchase")
                return .userCancelled
                
            case .pending:
                logger.info("Purchase pending")
                return .pending
                
            @unknown default:
                logger.warning("Unknown purchase result")
                return .failed(StoreKitError.unknown)
            }
        } catch {
            logger.error("Purchase failed: \(error.localizedDescription)")
            errorMessage = "Purchase failed. Please try again."
            return .failed(error)
        }
    }
    
    /// Restore previous purchases
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            logger.info("Purchases restored successfully")
        } catch {
            logger.error("Failed to restore purchases: \(error.localizedDescription)")
            errorMessage = "Failed to restore purchases. Please try again."
        }
        
        isLoading = false
    }
    
    // MARK: - Transaction Handling
    
    /// Listen for transaction updates
    /// - Returns: Task that listens for transaction updates
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    
                    await self.updateSubscriptionStatus()
                    
                    await transaction.finish()
                } catch {
                    self.logger.error("Transaction verification failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Verify a transaction result
    /// - Parameter result: Verification result to check
    /// - Returns: Verified transaction
    /// - Throws: Error if verification fails
    private func checkVerified<T>(_ result: VerificationResult<T>) async throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Subscription Status
    
    /// Update the current subscription status
    func updateSubscriptionStatus() async {
        var activeSubscription: Transaction?
        var expirationDate: Date?
        
        // Check all subscription products for active subscriptions
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try await checkVerified(result)
                
                // Check if this is a subscription
                if let status = await transaction.subscriptionStatus {
                    // Check if subscription is active
                    switch status.state {
                    case .subscribed:
                        activeSubscription = transaction
                        // Get expiration date from transaction
                        expirationDate = transaction.expirationDate
                        
                    case .inGracePeriod:
                        subscriptionStatus = .inGracePeriod
                        expirationDate = transaction.expirationDate
                        return
                        
                    case .inBillingRetryPeriod:
                        subscriptionStatus = .inBillingRetry
                        expirationDate = transaction.expirationDate
                        return
                        
                    case .revoked, .expired:
                        subscriptionStatus = .expired
                        
                    default:
                        break
                    }
                }
                
                // Update purchased product IDs
                if transaction.revocationDate == nil {
                    purchasedProductIDs.insert(transaction.productID)
                } else {
                    purchasedProductIDs.remove(transaction.productID)
                }
            } catch {
                logger.error("Failed to verify transaction: \(error.localizedDescription)")
            }
        }
        
        // Update final status
        if activeSubscription != nil {
            subscriptionStatus = .subscribed(expirationDate: expirationDate)
        } else if subscriptionStatus != .expired {
            subscriptionStatus = .notSubscribed
        }
        
        logger.info("Subscription status updated: \(String(describing: self.subscriptionStatus))")
    }
    
    // MARK: - Subscription Info
    
    /// Check if user has an active subscription
    var hasActiveSubscription: Bool {
        subscriptionStatus.isActive
    }
    
    /// Get the active subscription product ID if available
    var activeSubscriptionProductID: String? {
        guard hasActiveSubscription else { return nil }
        return purchasedProductIDs.first
    }
    
    /// Get formatted expiration date
    var formattedExpirationDate: String? {
        guard case .subscribed(let expirationDate) = subscriptionStatus,
              let date = expirationDate else {
            return nil
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - StoreKit Errors

enum StoreKitError: LocalizedError {
    case failedVerification
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Transaction verification failed"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

