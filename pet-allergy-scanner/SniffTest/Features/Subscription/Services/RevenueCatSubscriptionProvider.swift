//
//  RevenueCatSubscriptionProvider.swift
//  SniffTest
//
//  RevenueCat-backed subscription service responsible for offerings, purchases, and entitlement state.
//

import Foundation
import RevenueCat
import os.log

/// RevenueCat configuration container used to initialize the subscription provider.
struct RevenueCatConfiguration: Equatable {
    let apiKey: String
    let entitlementID: String
}

/// Subscription provider contract that exposes the operations required by the UI layer.
@MainActor
protocol SubscriptionProviding: ObservableObject {
    var products: [SubscriptionProduct] { get }
    var subscriptionStatus: SubscriptionStatus { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    var hasActiveSubscription: Bool { get }
    var formattedExpirationDate: String? { get }
    func configure(with configuration: RevenueCatConfiguration)
    func refreshOfferings() async
    func refreshCustomerInfo() async
    func purchase(_ product: SubscriptionProduct) async -> PurchaseResult
    func restorePurchases() async
}

// MARK: - RevenueCat Subscription Provider

/// RevenueCat-backed subscription provider that manages offerings, purchases, and entitlement status.
@MainActor
final class RevenueCatSubscriptionProvider: NSObject, SubscriptionProviding {
    static let shared = RevenueCatSubscriptionProvider()

    @Published private(set) var products: [SubscriptionProduct] = []
    @Published private(set) var subscriptionStatus: SubscriptionStatus = .notSubscribed
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let logger = Logger(subsystem: "com.snifftest.app", category: "RevenueCat")
    private var configuration = RevenueCatConfiguration(apiKey: "", entitlementID: "")
    private var hasConfiguredSDK = false
    private var activeEntitlementIDs: Set<String> = []
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private override init() {}

    /// Configure the RevenueCat SDK and prime initial data loads.
    /// - Parameter configuration: RevenueCat API key and entitlement identifier.
    func configure(with configuration: RevenueCatConfiguration) {
        guard configuration.apiKey != self.configuration.apiKey || configuration.entitlementID != self.configuration.entitlementID else { return }

        self.configuration = configuration

        guard !configuration.apiKey.isEmpty else {
            errorMessage = "RevenueCat API key is missing. Update Info.plist before enabling subscriptions."
            logger.error("RevenueCat configuration failed: missing API key.")
            return
        }

        guard !hasConfiguredSDK else {
            Task {
                await refreshOfferings()
                await refreshCustomerInfo()
            }
            return
        }

        Purchases.logLevel = Configuration.isDebugMode ? .info : .warn
        Purchases.configure(withAPIKey: configuration.apiKey)
        Purchases.shared.delegate = self
        hasConfiguredSDK = true
        logger.info("RevenueCat configured successfully.")

        Task {
            await refreshOfferings()
            await refreshCustomerInfo()
        }
    }

    /// Refresh available offerings from RevenueCat.
    func refreshOfferings() async {
        guard hasConfiguredSDK else {
            logger.warning("Skipping offerings refresh because RevenueCat SDK is not configured.")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let offerings = try await loadOfferings()
            let packages = offerings?.current?.availablePackages ?? []
            let mappedProducts = packages.map { package in
                SubscriptionProduct(id: package.storeProduct.productIdentifier, package: package)
            }
            products = mappedProducts.sorted { lhs, rhs in
                lhs.package.storeProduct.price < rhs.package.storeProduct.price
            }
            logger.info("Loaded \(self.products.count) RevenueCat packages.")
        } catch {
            logger.error("Failed to load RevenueCat offerings: \(error.localizedDescription)")
            errorMessage = "Unable to load subscription options. Please try again."
        }

        isLoading = false
    }

    private func loadOfferings() async throws -> Offerings? {
        try await withCheckedThrowingContinuation { continuation in
            Purchases.shared.getOfferings { offerings, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: offerings)
            }
        }
    }

    /// Refresh customer info and update entitlement state.
    func refreshCustomerInfo() async {
        guard hasConfiguredSDK else {
            logger.warning("Skipping customer info refresh because RevenueCat SDK is not configured.")
            return
        }

        do {
            let info = try await loadCustomerInfo()
            applyCustomerInfo(info)
        } catch {
            logger.error("Failed to refresh customer info: \(error.localizedDescription)")
            errorMessage = "Unable to verify subscription status. Please try again."
        }
    }

    private func loadCustomerInfo() async throws -> CustomerInfo {
        try await withCheckedThrowingContinuation { continuation in
            Purchases.shared.getCustomerInfo { info, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let info else {
                    continuation.resume(throwing: NSError(domain: "RevenueCatSubscriptionProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing customer info response."]))
                    return
                }

                continuation.resume(returning: info)
            }
        }
    }

    private func applyCustomerInfo(_ info: CustomerInfo) {
        let wasSubscribedBefore = hasActiveSubscription
        activeEntitlementIDs = Set(info.entitlements.active.keys)
        updateSubscriptionStatus(using: info)
        logger.debug("Customer info updated. Active entitlements: \(self.activeEntitlementIDs.joined(separator: ", ")), Status: \(self.subscriptionStatus)")
        
        // Track subscription status changes
        if hasActiveSubscription && !wasSubscribedBefore {
            // Subscription just became active (could be new purchase or restore)
            // Note: Specific purchase tracking happens in purchase() method
            PostHogAnalytics.updateUserRole("premium")
            logger.info("Subscription became active. Syncing with backend...")
            
            // Sync subscription status with backend when subscription becomes active
            Task {
                await syncSubscriptionWithBackend()
            }
        } else if !hasActiveSubscription && wasSubscribedBefore {
            // Subscription just expired or was cancelled
            PostHogAnalytics.updateUserRole("free")
        }
        // Only sync when subscription becomes active to avoid unnecessary API calls
    }
    
    /// Sync subscription status with backend API
    /// This ensures the backend knows about the subscription state from RevenueCat
    private func syncSubscriptionWithBackend() async {
        guard hasActiveSubscription else {
            logger.debug("No active subscription to sync with backend")
            return
        }
        
        do {
            // Call backend subscription status endpoint to verify and sync
            // The backend will verify the subscription via RevenueCat webhooks
            // This is a secondary check to ensure consistency
            let apiService = APIService.shared
            let _ = try await apiService.get(
                endpoint: "/subscriptions/status",
                responseType: SubscriptionStatusResponse.self
            )
            logger.info("Successfully synced subscription status with backend")
        } catch {
            logger.error("Failed to sync subscription with backend: \(error.localizedDescription)")
            // Don't throw - this is a background sync, not critical to user flow
        }
    }

    /// Purchase a subscription product using RevenueCat.
    /// - Parameter product: Subscription product built from a RevenueCat package.
    /// - Returns: Purchase result describing the transaction outcome.
    func purchase(_ product: SubscriptionProduct) async -> PurchaseResult {
        guard hasConfiguredSDK else {
            logger.error("Attempted to purchase without configuring RevenueCat SDK.")
            return .failed(NSError(domain: "RevenueCatSubscriptionProvider", code: -2, userInfo: [NSLocalizedDescriptionKey: "Subscriptions are not configured."]))
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let result = try await performPurchase(for: product.package)

            if result.userCancelled {
                logger.info("User cancelled RevenueCat purchase for package \(product.id, privacy: .public).")
                return .userCancelled
            }

            guard let info = result.customerInfo else {
                logger.error("RevenueCat purchase completed without customer info payload.")
                return .failed(NSError(domain: "RevenueCatSubscriptionProvider", code: -3, userInfo: [NSLocalizedDescriptionKey: "Missing customer info after purchase."]))
            }

            let wasSubscribedBefore = hasActiveSubscription
            applyCustomerInfo(info)
            
            // Track premium upgrade if subscription just became active
            if hasActiveSubscription && !wasSubscribedBefore {
                let tier = determineTier(from: product.id)
                PostHogAnalytics.trackPremiumUpgrade(tier: tier, productId: product.id)
            }
            
            logger.info("RevenueCat purchase successful for package \(product.id, privacy: .public).")
            return .success
        } catch {
            logger.error("RevenueCat purchase failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Purchase failed. Please try again."
            return .failed(error)
        }
    }

    private func performPurchase(for package: Package) async throws -> (customerInfo: CustomerInfo?, userCancelled: Bool) {
        try await withCheckedThrowingContinuation { continuation in
            Purchases.shared.purchase(package: package) { _, customerInfo, error, userCancelled in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (customerInfo, userCancelled))
            }
        }
    }

    /// Restore purchases and refresh entitlement state.
    func restorePurchases() async {
        guard hasConfiguredSDK else {
            logger.warning("Skipping restore because RevenueCat SDK is not configured.")
            return
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let info = try await performRestore()
            applyCustomerInfo(info)
            logger.info("RevenueCat restore succeeded. Active entitlements: \(self.activeEntitlementIDs, privacy: .public)")
        } catch {
            logger.error("RevenueCat restore failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Unable to restore purchases. Please try again."
        }
    }

    private func performRestore() async throws -> CustomerInfo {
        try await withCheckedThrowingContinuation { continuation in
            Purchases.shared.restorePurchases { info, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let info else {
                    continuation.resume(throwing: NSError(domain: "RevenueCatSubscriptionProvider", code: -4, userInfo: [NSLocalizedDescriptionKey: "Missing customer info after restore."]))
                    return
                }

                continuation.resume(returning: info)
            }
        }
    }

    private func updateSubscriptionStatus(using info: CustomerInfo) {
        guard !configuration.entitlementID.isEmpty else {
            subscriptionStatus = .notSubscribed
            return
        }

        guard let entitlement = info.entitlements.all[configuration.entitlementID] else {
            subscriptionStatus = .notSubscribed
            return
        }

        if entitlement.isActive {
            if let billingIssueDate = entitlement.billingIssueDetectedAt {
                logger.warning("RevenueCat reported billing issue on \(billingIssueDate as NSDate).")
                subscriptionStatus = .inBillingRetry
                return
            }

            // Check if we're in a grace period by checking if unsubscribeDetectedAt exists
            // but the entitlement is still active
            if entitlement.unsubscribeDetectedAt != nil {
                subscriptionStatus = .inGracePeriod
                return
            }

            subscriptionStatus = .subscribed(expirationDate: entitlement.expirationDate)
            return
        }

        if let expirationDate = entitlement.expirationDate, expirationDate < Date() {
            subscriptionStatus = .expired
            return
        }

        subscriptionStatus = .notSubscribed
    }

    var hasActiveSubscription: Bool {
        subscriptionStatus.isActive
    }

    var formattedExpirationDate: String? {
        guard case .subscribed(let expirationDate) = subscriptionStatus,
              let expirationDate else {
            return nil
        }
        return dateFormatter.string(from: expirationDate)
    }
    
    /// Determine subscription tier from product ID
    /// - Parameter productId: Product identifier
    /// - Returns: Tier string (weekly, monthly, yearly)
    private func determineTier(from productId: String) -> String {
        let lowercased = productId.lowercased()
        if lowercased.contains("weekly") {
            return "weekly"
        } else if lowercased.contains("yearly") || lowercased.contains("annual") {
            return "yearly"
        } else {
            return "monthly" // Default
        }
    }
}

extension RevenueCatSubscriptionProvider: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor [weak self] in
            self?.applyCustomerInfo(customerInfo)
        }
    }
}

/// Response model for backend subscription status endpoint
struct SubscriptionStatusResponse: Codable {
    let hasSubscription: Bool
    let status: String?
    let expiresAt: Date?
    let productId: String?
    
    enum CodingKeys: String, CodingKey {
        case hasSubscription = "has_subscription"
        case status
        case expiresAt = "expires_at"
        case productId = "product_id"
    }
}

