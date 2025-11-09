//
//  SubscriptionProduct.swift
//  SniffTest
//
//  Subscription product models and identifiers
//

import Foundation
import RevenueCat

/// Represents a subscription product available for purchase
struct SubscriptionProduct: Identifiable {
    let id: String
    let package: Package
    
    private var storeProduct: StoreProduct { package.storeProduct }

    /// Display title for the subscription
    var title: String { storeProduct.localizedTitle }
    
    /// User-friendly plan label derived from the product identifier
    var planLabel: String {
        if let mapped = SubscriptionProductID(rawValue: id)?.displayName {
            return mapped
        }
        if let suggested = displayName(for: package.packageType) {
            return suggested
        }
        return storeProduct.localizedTitle
    }
    
    /// Formatted price string
    var price: String {
        storeProduct.localizedPriceString
    }
    
    /// Subscription duration description
    var duration: String {
        guard let period = storeProduct.subscriptionPeriod else { return "" }
        
        switch period.unit {
        case .day:
            return period.value == 1 ? "per day" : "per \(period.value) days"
        case .week:
            return period.value == 1 ? "per week" : "per \(period.value) weeks"
        case .month:
            return period.value == 1 ? "per month" : "per \(period.value) months"
        case .year:
            return period.value == 1 ? "per year" : "per \(period.value) years"
        @unknown default:
            return ""
        }
    }
    
    /// Calculate savings percentage compared to another product
    /// - Parameter other: The product to compare against
    /// - Returns: Formatted savings string or nil
    func savings(comparedTo other: SubscriptionProduct) -> String? {
        guard storeProduct.subscriptionPeriod != nil,
              other.storeProduct.subscriptionPeriod != nil else {
            return nil
        }
        
        let thisMonthlyPrice = monthlyEquivalentPrice(for: storeProduct)
        let otherMonthlyPrice = monthlyEquivalentPrice(for: other.storeProduct)
        
        guard otherMonthlyPrice > 0 else { return nil }
        
        let savingsPercent = ((otherMonthlyPrice - thisMonthlyPrice) / otherMonthlyPrice) * 100
        let percentValue = NSDecimalNumber(decimal: savingsPercent).doubleValue
        guard percentValue > 0 else { return nil }
        
        let formattedPercent: String
        if percentValue >= 10 {
            formattedPercent = String(format: "%.0f", round(percentValue))
        } else {
            formattedPercent = String(format: "%.1f", percentValue)
        }
        
        return "Save \(formattedPercent)% vs \(other.planLabel)"
    }
    
    /// Calculate monthly equivalent price for comparison
    private func monthlyEquivalentPrice(for product: StoreProduct) -> Decimal {
        guard let period = product.subscriptionPeriod else { return 0 }
        
        let price = product.price
        
        switch period.unit {
        case .day:
            return price * 30 / Decimal(period.value)
        case .week:
            return price * 4 / Decimal(period.value)
        case .month:
            return price / Decimal(period.value)
        case .year:
            return price / (12 * Decimal(period.value))
        @unknown default:
            return price
        }
    }

    /// Provide a readable plan name from the RevenueCat package type when possible.
    /// - Parameter packageType: RevenueCat package type derived from the dashboard setup.
    /// - Returns: Optional display string for the plan.
    private func displayName(for packageType: PackageType) -> String? {
        switch packageType {
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        case .annual:
            return "Yearly"
        case .lifetime:
            return "Lifetime"
        case .sixMonth:
            return "6 Months"
        case .threeMonth:
            return "3 Months"
        case .twoMonth:
            return "2 Months"
        case .unknown, .custom:
            return nil
        @unknown default:
            return nil
        }
    }
}

/// Product identifiers for in-app purchases
enum SubscriptionProductID: String, CaseIterable {
    case weekly = "sniffweekly"
    case monthly = "sniffmonthly"
    case yearly = "sniffyearly"
    
    var displayName: String {
        switch self {
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        case .yearly:
            return "Yearly"
        }
    }
}

/// Subscription status
enum SubscriptionStatus: Equatable {
    case notSubscribed
    case subscribed(expirationDate: Date?)
    case expired
    case inGracePeriod
    case inBillingRetry
    
    var isActive: Bool {
        switch self {
        case .subscribed, .inGracePeriod, .inBillingRetry:
            return true
        case .notSubscribed, .expired:
            return false
        }
    }
}

/// Transaction result for purchase operations
enum PurchaseResult {
    case success
    case userCancelled
    case pending
    case failed(Error)
}

