# RevenueCat Server Migration Guide

## Overview

This guide explains how to migrate from direct App Store receipt validation to RevenueCat's webhook-based subscription management.

## Benefits of RevenueCat

1. **Unified API** - Same backend code works for iOS and Android
2. **Automatic Receipt Validation** - RevenueCat handles all App Store communication
3. **Real-time Updates** - Webhooks provide instant subscription status changes
4. **Better Analytics** - Built-in dashboard for subscription metrics
5. **Reduced Complexity** - No need to parse receipts or handle App Store API quirks

## Migration Steps

### 1. Environment Variables

Add to your `.env` or environment configuration:

```bash
# RevenueCat API Keys (get from https://app.revenuecat.com)
REVENUECAT_API_KEY=your_revenuecat_api_key_here
REVENUECAT_WEBHOOK_SECRET=your_webhook_secret_here

# These are already in your iOS app Info.plist
REVENUECAT_PUBLIC_SDK_KEY=test_MOlfphEwuRvEwGfgBdUDfjZFgVJ
REVENUECAT_ENTITLEMENT_ID=pro_user
```

### 2. Update Router Registration

In `server/app/main.py` or your API router configuration:

```python
from app.api.v1.subscriptions import revenuecat_webhook

# Add RevenueCat webhook router
app.include_router(
    revenuecat_webhook.router,
    prefix="/api/v1/subscriptions/revenuecat",
    tags=["subscriptions"]
)
```

### 3. Configure RevenueCat Dashboard

#### A. Set Up Webhook URL

1. Go to https://app.revenuecat.com
2. Navigate to your project → Settings → Integrations
3. Add webhook URL: `https://your-api-domain.com/api/v1/subscriptions/revenuecat/webhook`
4. Generate and save the webhook authorization secret

#### B. Configure Products & Entitlements

1. **Products** → Add your App Store product IDs:
   - `sniffweekly`
   - `sniffmonthly`
   - `sniffyearly`
   - `weekly`
   - `monthly`
   - `yearly`

2. **Entitlements** → Create entitlement:
   - Identifier: `pro_user`
   - Name: "Premium Access"
   - Attach all your products to this entitlement

3. **Offerings** → Create offering:
   - Identifier: `default`
   - Add packages for each product
   - Set as "Current" offering

### 4. Database Schema Updates

Ensure your `subscriptions` table has these columns:

```sql
CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(50) NOT NULL,  -- active, cancelled, expired, billing_issue, paused
    product_id VARCHAR(100) NOT NULL,
    entitlement_id VARCHAR(100) NOT NULL,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id)
);

CREATE INDEX idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_subscriptions_expires_at ON subscriptions(expires_at);
```

### 5. Update iOS App Sync Logic

In your iOS app's `SubscriptionViewModel`, update the backend sync:

```swift
private func syncSubscriptionWithBackend() async {
    guard subscriptionProvider.hasActiveSubscription else { return }
    
    // RevenueCat webhooks automatically update the backend
    // You only need to refresh local state from your API
    do {
        let response = try await APIClient.shared.request(
            endpoint: "/subscriptions/status",
            method: .get
        )
        
        // Update local user role if needed
        if response.has_subscription {
            await authService.refreshUserProfile()
        }
    } catch {
        logger.error("Failed to sync subscription: \(error.localizedDescription)")
    }
}
```

### 6. Testing Webhooks Locally

Use ngrok or similar to test webhooks locally:

```bash
# Start ngrok
ngrok http 8000

# Update RevenueCat webhook URL to:
# https://your-ngrok-url.ngrok.io/api/v1/subscriptions/revenuecat/webhook

# Make test purchase in iOS app
# Check server logs for webhook events
```

### 7. RevenueCat Event Types

Your server will receive these webhook events:

| Event Type | Description | Action |
|------------|-------------|--------|
| `INITIAL_PURCHASE` | First purchase | Activate subscription, upgrade to premium |
| `RENEWAL` | Auto-renewal | Update expiration date |
| `CANCELLATION` | User cancelled | Mark as cancelled (keep access until expiry) |
| `UNCANCELLATION` | Re-enabled auto-renew | Restore active status |
| `EXPIRATION` | Subscription expired | Downgrade to free |
| `BILLING_ISSUE` | Payment failed | Mark billing issue, notify user |
| `NON_RENEWING_PURCHASE` | One-time purchase | Handle consumables |
| `SUBSCRIBER_ALIAS` | User identified | Merge anonymous → identified |
| `SUBSCRIPTION_PAUSED` | Paused (Android) | Mark as paused |
| `TRANSFER` | Transferred subscription | Update both users |

### 8. Monitoring & Debugging

#### Check Webhook Delivery

1. RevenueCat Dashboard → Your App → Webhooks
2. View delivery history and retry failed events
3. Check response codes and payloads

#### Server Logs

```python
# Enable debug logging for RevenueCat events
import logging
logging.getLogger("app.services.revenuecat_service").setLevel(logging.DEBUG)
```

#### Test Subscription Status

```bash
# Query subscriber from RevenueCat API
curl -X GET "https://api.revenuecat.com/v1/subscribers/USER_ID" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json"
```

### 9. Gradual Migration Strategy

You can run both systems in parallel during migration:

1. **Phase 1**: Keep existing App Store endpoints active
2. **Phase 2**: Add RevenueCat webhook handler
3. **Phase 3**: Update iOS app to use RevenueCat SDK
4. **Phase 4**: Monitor both systems for consistency
5. **Phase 5**: Deprecate direct App Store endpoints

### 10. Security Best Practices

✅ **Always verify webhook signatures**
```python
def _verify_webhook_signature(body: str, signature: str) -> bool:
    # CRITICAL: Never skip signature verification
    expected = hmac.new(secret, body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(signature, expected)
```

✅ **Use HTTPS only**
- RevenueCat only sends webhooks to HTTPS URLs

✅ **Rate limiting**
- Implement rate limiting on webhook endpoints

✅ **Idempotency**
- Handle duplicate webhook deliveries gracefully

❌ **Don't expose API keys in client code**
- Only use public SDK key in iOS app
- Keep private API key server-side only

## Comparison: Before vs After

### Before (Direct App Store)

```python
# Complex receipt validation
receipt_data = base64.decode(receipt)
response = await httpx.post(
    "https://buy.itunes.apple.com/verifyReceipt",
    json={"receipt-data": receipt_data, "password": shared_secret}
)
# Parse complex response
# Handle sandbox fallback
# Extract latest transaction
# Validate signature
# Update database
```

### After (RevenueCat)

```python
# Simple webhook handler
@router.post("/webhook")
async def handle_webhook(request: Request):
    payload = await request.json()
    
    if payload["type"] == "INITIAL_PURCHASE":
        await activate_subscription(payload["event"])
    
    return {"status": "success"}
```

## Troubleshooting

### Webhook Not Firing

1. Check webhook URL is correct in RevenueCat dashboard
2. Ensure URL is publicly accessible (not localhost)
3. Verify HTTPS certificate is valid
4. Check server logs for incoming requests

### Signature Verification Failing

1. Confirm `REVENUECAT_WEBHOOK_SECRET` matches dashboard
2. Check you're using raw request body (not parsed JSON)
3. Verify header name: `X-RevenueCat-Signature`

### Subscription Status Out of Sync

1. Use RevenueCat API to query real-time status
2. Trigger manual webhook retry from dashboard
3. Check for failed webhook deliveries

## Support Resources

- RevenueCat Docs: https://docs.revenuecat.com
- Webhook Events: https://www.revenuecat.com/docs/webhooks
- API Reference: https://www.revenuecat.com/reference/basic
- Community: https://community.revenuecat.com
- Support: support@revenuecat.com

## Questions?

For implementation help:
1. Check RevenueCat documentation
2. Review webhook event logs in dashboard
3. Test with sample webhooks
4. Contact RevenueCat support if needed

