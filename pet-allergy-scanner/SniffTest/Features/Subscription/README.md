# Subscription Module - StoreKit 2 Implementation

## Overview

This module implements a complete subscription system using Apple's StoreKit 2 framework. It follows SOLID, DRY, and KISS principles with proper separation of concerns.

## Architecture

### Models (`Models/`)
- **SubscriptionProduct.swift** - Models for subscription products and their metadata
  - `SubscriptionProduct`: Wrapper around StoreKit Product with convenience properties
  - `SubscriptionProductID`: Enum defining available subscription products
  - `SubscriptionStatus`: Enum representing current subscription state
  - `PurchaseResult`: Result type for purchase operations

### Services (`Services/`)
- **StoreKitService.swift** - Core service managing StoreKit operations
  - Product loading and caching
  - Purchase processing and verification
  - Transaction monitoring
  - Subscription status management
  - Receipt verification

### ViewModels (`ViewModels/`)
- **SubscriptionViewModel.swift** - View model managing subscription UI state
  - Product selection
  - Purchase flow management
  - Error handling
  - Backend synchronization
  - Alert state management

### Views (`Views/`)
- **SubscriptionView.swift** - Main subscription UI
  - Current plan status display
  - Feature comparison
  - Pricing options
  - Purchase flow
  - Subscription management

## Product Configuration

### Subscription Products (Synced with App Store Connect)

1. **Weekly Subscription**
   - Product ID: `sniffweekly`
   - Internal ID: `6755076045`
   - Price: $2.99/week
   - Auto-renewable
   - Group Number: 1

2. **Monthly Subscription**
   - Product ID: `sniffmonthly`
   - Internal ID: `6755076046`
   - Price: $6.99/month
   - Auto-renewable
   - Group Number: 2

3. **Yearly Subscription** (Best Value)
   - Product ID: `sniffyearly`
   - Internal ID: `6755075940`
   - Price: $39.99/year
   - Auto-renewable
   - Group Number: 3
   - Shows significant savings vs weekly/monthly

## Setup Instructions

### 1. App Store Connect Configuration

✅ **Already Completed!** Your subscription group "main-subs" (ID: 21827913) is configured with:
   - Weekly: `sniffweekly` ($2.99/week)
   - Monthly: `sniffmonthly` ($6.99/month)
   - Yearly: `sniffyearly` ($39.99/year)

Your Configuration.storekit file is synced with App Store Connect.

### 2. Xcode Project Configuration

The following have already been configured:

- ✅ Entitlements file updated with in-app purchase capability
- ✅ StoreKit configuration file created (`Configuration.storekit`)
- ✅ All necessary Swift files implemented

### 3. Testing with StoreKit Configuration File

The project includes `Configuration.storekit` for local testing:

1. In Xcode, go to Product → Scheme → Edit Scheme
2. Select "Run" from the left sidebar
3. Go to the "Options" tab
4. Under "StoreKit Configuration", select `Configuration.storekit`
5. Run the app in the simulator or on a device

This allows testing purchases without connecting to App Store Connect or using sandbox accounts.

### 4. Testing with Sandbox Accounts

For testing on real devices before release:

1. Create sandbox test accounts in App Store Connect
2. Sign out of your Apple ID in Settings → App Store
3. Run the app and make a purchase
4. Sign in with sandbox account when prompted

## Usage

### Basic Integration

```swift
import SwiftUI

struct MyView: View {
    @StateObject private var viewModel = SubscriptionViewModel()
    
    var body: some View {
        SubscriptionView()
            .environmentObject(AuthService.shared)
    }
}
```

### Checking Subscription Status

```swift
let storeKitService = StoreKitService.shared

// Check if user has active subscription
if storeKitService.hasActiveSubscription {
    // User is premium
}

// Get specific status
switch storeKitService.subscriptionStatus {
case .subscribed(let expirationDate):
    print("Active until: \(expirationDate ?? Date())")
case .inGracePeriod:
    print("In grace period")
case .inBillingRetry:
    print("Payment issue")
case .expired:
    print("Expired")
case .notSubscribed:
    print("No subscription")
}
```

### Manual Purchase Flow

```swift
let viewModel = SubscriptionViewModel()

// Purchase selected product
Task {
    await viewModel.purchaseSubscription()
}

// Restore purchases
Task {
    await viewModel.restorePurchases()
}
```

## Features

### Implemented Features

- ✅ Product loading from App Store
- ✅ Purchase processing with verification
- ✅ Transaction monitoring and updates
- ✅ Subscription status tracking
- ✅ Restore purchases functionality
- ✅ Grace period handling
- ✅ Billing retry handling
- ✅ Error handling with user feedback
- ✅ Loading states
- ✅ Savings calculation
- ✅ Beautiful UI following design system

### Premium Features

Users with active subscriptions gain access to:
- Unlimited scans
- Advanced allergen detection
- Detailed analytics
- Unlimited pets
- Priority support
- Early access to new features

## Backend Integration

The subscription system includes hooks for backend synchronization:

```swift
// In SubscriptionViewModel.swift
private func syncSubscriptionWithBackend() async {
    // TODO: Implement backend sync
    // Verify receipt with your server
    // Update user role in database
}
```

### Recommended Backend Flow

1. Client makes purchase → StoreKit validates
2. Client sends receipt to backend
3. Backend verifies with Apple's servers
4. Backend updates user's subscription status
5. Backend returns confirmation to client
6. Client updates local state

## Security Considerations

1. **Transaction Verification**: All transactions are verified using StoreKit's built-in verification
2. **Receipt Validation**: Should be implemented on backend for production
3. **Secure Storage**: Subscription status managed by StoreKit, no manual storage needed
4. **Server-Side Validation**: Recommended to prevent fraud

## File Structure

```
Features/Subscription/
├── Models/
│   └── SubscriptionProduct.swift
├── Services/
│   └── StoreKitService.swift
├── ViewModels/
│   └── SubscriptionViewModel.swift
├── Views/
│   └── SubscriptionView.swift
├── Configuration.storekit
└── README.md (this file)
```

## Dependencies

- **StoreKit 2**: Apple's framework for in-app purchases
- **SwiftUI**: UI framework
- **Combine**: For reactive state management

## Testing

### Unit Testing

```swift
// Test subscription status
func testSubscriptionStatus() async {
    let service = StoreKitService.shared
    await service.updateSubscriptionStatus()
    XCTAssertNotNil(service.subscriptionStatus)
}
```

### UI Testing

- Test purchase flow
- Test restore functionality
- Test subscription management
- Test error states

## Troubleshooting

### Products Not Loading

1. Check Product IDs match exactly in code and App Store Connect
2. Verify StoreKit configuration file is selected in scheme
3. Check internet connection (for real App Store)
4. Wait a few minutes after creating products in App Store Connect

### Purchase Fails

1. Check sandbox account is properly configured
2. Verify entitlements are correct
3. Check device/simulator has internet access
4. Review error messages in console

### Status Not Updating

1. Ensure `updateSubscriptionStatus()` is called after purchase
2. Check transaction listener is running
3. Verify StoreKit Service singleton is initialized

## Best Practices

1. **Always verify transactions** before granting access
2. **Handle all subscription states** (grace period, billing retry, etc.)
3. **Provide clear error messages** to users
4. **Test thoroughly** with StoreKit configuration file
5. **Implement server-side validation** for production
6. **Monitor subscription metrics** in App Store Connect
7. **Handle subscription changes** (upgrades, downgrades, cancellations)
8. **Respect user privacy** - don't collect unnecessary data

## Future Enhancements

- [ ] Promotional offers
- [ ] Introductory pricing variations
- [ ] Subscription groups (multiple tiers)
- [ ] Family sharing support
- [ ] Analytics integration
- [ ] A/B testing for pricing
- [ ] Custom paywall designs
- [ ] Winback offers for churned users

## References

- [StoreKit 2 Documentation](https://developer.apple.com/documentation/storekit)
- [In-App Purchase Best Practices](https://developer.apple.com/app-store/in-app-purchase/)
- [Testing In-App Purchases](https://developer.apple.com/documentation/storekit/in-app_purchase/testing_in-app_purchases_with_sandbox)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

## Support

For questions or issues with the subscription implementation, please contact the development team or refer to the main project documentation.

---

**Version**: 1.0.0  
**Last Updated**: November 8, 2025  
**Swift Version**: 6.0  
**Minimum iOS**: 17.1

