//
//  SubscriptionProduct.swift
//  SniffTest
//
//  Subscription product models and identifiers
//

import Foundation
import StoreKit

/// Represents a subscription product available for purchase
struct SubscriptionProduct: Identifiable {
    let id: String
    let product: Product
    
    /// Display title for the subscription
    var title: String { product.displayName }
    
    /// User-friendly plan label derived from the product identifier
    var planLabel: String {
        SubscriptionProductID(rawValue: id)?.displayName ?? product.displayName
    }
    
    /// Formatted price string
    var price: String {
        product.displayPrice
    }
    
    /// Subscription duration description
    var duration: String {
        guard let subscription = product.subscription else { return "" }
        
        let period = subscription.subscriptionPeriod
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
        guard product.subscription != nil,
              other.product.subscription != nil else {
            return nil
        }
        
        let thisMonthlyPrice = monthlyEquivalentPrice(for: product)
        let otherMonthlyPrice = monthlyEquivalentPrice(for: other.product)
        
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
    private func monthlyEquivalentPrice(for product: Product) -> Decimal {
        guard let subscription = product.subscription else { return 0 }
        
        let period = subscription.subscriptionPeriod
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

