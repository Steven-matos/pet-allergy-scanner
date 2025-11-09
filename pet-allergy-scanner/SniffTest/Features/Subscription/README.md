# Subscription Module – RevenueCat Integration

## Overview

The subscription feature now relies on RevenueCat to manage in-app purchase products, subscription status, and entitlement state. This abstraction replaces the earlier StoreKit 2-only flow while keeping the same SOLID, DRY, and KISS principles. RevenueCat handles receipt validation, entitlement caching, and paywall experiments from the dashboard, allowing the app to focus on presenting offerings and reacting to entitlement changes.

## Architecture

### Models (`Models/`)
- **SubscriptionProduct.swift** – Wraps RevenueCat `Package` / `StoreProduct` metadata
  - `SubscriptionProduct`: Lightweight wrapper with pricing helpers
  - `SubscriptionProductID`: Enum mapping App Store identifiers to display labels
  - `SubscriptionStatus`: Current entitlement state (active, grace period, billing retry, etc.)
  - `PurchaseResult`: Outcome of purchase attempts

### Services (`Services/`)
- **RevenueCatSubscriptionProvider.swift** – RevenueCat-backed subscription provider
  - Configures the SDK and assigns the delegate
  - Loads offerings and maps them to `SubscriptionProduct`
  - Performs purchases / restores through RevenueCat
  - Tracks entitlements and surfaces subscription status

### ViewModels (`ViewModels/`)
- **SubscriptionViewModel.swift** – SwiftUI-facing adapter
  - Observes the provider for changes via Combine
  - Manages product selection and purchase/restore flows
  - Triggers backend sync placeholders
  - Exposes UI alert state, loading state, and formatted expiration dates

### Views (`Views/`)
- **SubscriptionView.swift** – SwiftUI paywall experience
  - Displays plan benefits and active status
  - Lists available packages returned by RevenueCat
  - Provides upgrade / restore / manage actions

## Configuration

1. **Info.plist values**
   - `REVENUECAT_PUBLIC_SDK_KEY`: Public SDK key from the RevenueCat dashboard
   - `REVENUECAT_ENTITLEMENT_ID`: Entitlement identifier that unlocks premium access (default `premium`)
2. **RevenueCat dashboard**
   - Map App Store product identifiers (`sniffweekly`, `sniffmonthly`, `sniffyearly`) to the entitlement
   - Define offerings / packages to control what the app presents
3. **Xcode project**
   - RevenueCat added via Swift Package Manager (`https://github.com/RevenueCat/purchases-ios-spm.git`)
   - `RevenueCat` and `RevenueCatUI` frameworks linked to the app target
4. **App launch configuration**
   - `RevenueCatConfigurator.configure()` runs in `AppDelegate` to pass Info.plist values to `RevenueCatSubscriptionProvider`

## Usage

```swift
import SwiftUI

struct SubscriptionScene: View {
    @StateObject private var viewModel = SubscriptionViewModel()

    var body: some View {
        SubscriptionView()
            .environmentObject(AuthService.shared)
            .task {
                await viewModel.refreshStatus()
            }
    }
}
```

### Accessing subscription state

```swift
let provider = RevenueCatSubscriptionProvider.shared

if provider.hasActiveSubscription {
    // Unlock premium features
}

switch provider.subscriptionStatus {
case .subscribed(let expiration):
    print("Active until: \(String(describing: expiration))")
case .inGracePeriod:
    print("Within grace period")
case .inBillingRetry:
    print("Billing issue detected")
case .expired:
    print("Subscription expired")
case .notSubscribed:
    print("User is on the free tier")
}
```

### Triggering purchases

```swift
let subscriptionViewModel = SubscriptionViewModel()

Task {
    await subscriptionViewModel.purchaseSubscription()
}

Task {
    await subscriptionViewModel.restorePurchases()
}
```

## Testing

- **StoreKit Configuration** – `Configuration.storekit` remains available for UI previews, but RevenueCat recommends device testing with sandbox accounts to exercise the full server flow.
- **Sandbox accounts** – Use App Store Connect sandbox testers when validating purchases on physical devices.
- **Receipts & entitlements** – RevenueCat caches entitlements locally; use the dashboard’s customer view to inspect sandbox purchases if states appear inconsistent.

## Troubleshooting

| Issue | Steps |
| --- | --- |
| Offerings array is empty | Confirm offerings exist in the RevenueCat dashboard and API key is correct. Check known StoreKit 18.x simulator issues; test on device if necessary. |
| Purchase failed | Inspect the returned error, validate App Store product setup, ensure the sandbox account is signed in, and verify network access. |
| Entitlement not unlocking | Confirm `REVENUECAT_ENTITLEMENT_ID` matches the entitlement identifier in the dashboard. Review RevenueCat logs and backend verify flow. |
| Restore not finding purchases | Ensure sandbox transactions exist for the Apple ID being used. Verify the entitlement still exists and is active in RevenueCat. |

## Backend Integration

`SubscriptionViewModel.syncSubscriptionWithBackend()` remains the hook to inform the API once RevenueCat signals an active entitlement. Recommended production flow:

1. Client completes purchase through RevenueCat
2. Client sends the latest App Store receipt or RevenueCat customer info token to backend
3. Backend verifies the receipt (RevenueCat webhooks or App Store Server API)
4. Backend updates persistent premium status
5. Client refreshes auth/session state

## File Structure

```
Features/Subscription/
├── Models/
│   └── SubscriptionProduct.swift
├── Services/
│   └── RevenueCatSubscriptionProvider.swift
├── ViewModels/
│   └── SubscriptionViewModel.swift
├── Views/
│   └── SubscriptionView.swift
├── Configuration.storekit
└── README.md (this file)
```

## References

- [RevenueCat iOS SDK Docs](https://www.revenuecat.com/docs/getting-started/installation/ios)
- [RevenueCat Offerings & Packages](https://www.revenuecat.com/docs/getting-started/entitlements/offerings)
- [Known StoreKit Issues (2025)](https://www-docs.revenuecat.com/docs/known-store-issues)
- [Apple In-App Purchase Guidelines](https://developer.apple.com/app-store/guidelines/#in-app-purchase)

_Last updated: November 9, 2025_

