# Server-Side Subscription Setup Guide

## Overview

This guide covers setting up the backend infrastructure for App Store subscriptions using StoreKit 2.

## 📋 Prerequisites

- ✅ App Store Connect subscriptions configured
- ✅ iOS app with StoreKit 2 implementation
- ✅ FastAPI backend running
- ✅ Supabase database access

## 🗄️ Database Setup

### Step 1: Create Subscriptions Table

Run the SQL schema to create the subscriptions table:

```bash
psql $DATABASE_URL -f database_schemas/04_subscriptions_table.sql
```

Or apply via Supabase SQL Editor:
1. Go to Supabase Dashboard → SQL Editor
2. Copy contents of `database_schemas/04_subscriptions_table.sql`
3. Execute the SQL

### Step 2: Verify Table Creation

```sql
SELECT * FROM public.subscriptions LIMIT 1;
```

## 🔑 Environment Variables

Add these to your `.env` file:

```bash
# App Store Configuration
APPLE_SHARED_SECRET=your_shared_secret_from_app_store_connect

# Optional: For App Store Server Notifications
APPLE_WEBHOOK_SECRET=your_webhook_secret
```

### Getting Your Shared Secret

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Navigate to: My Apps → Your App → In-App Purchases → App-Specific Shared Secret
3. Click "Generate" if you don't have one
4. Copy and add to your environment variables

## 🚀 API Endpoints

### 1. Verify Subscription (POST `/api/v1/subscriptions/verify`)

Called after a successful purchase in the iOS app.

**Request:**
```json
{
  "receipt_data": "base64_encoded_receipt_data",
  "password": "your_shared_secret",
  "exclude_old_transactions": true
}
```

**Response:**
```json
{
  "success": true,
  "subscription": {
    "user_id": "uuid",
    "product_id": "sniffyearly",
    "tier": "yearly",
    "status": "active",
    "expiration_date": "2026-01-15T10:30:00Z",
    "auto_renew": true
  },
  "environment": "production"
}
```

### 2. Get Subscription Status (GET `/api/v1/subscriptions/status`)

Check current user's subscription status.

**Response:**
```json
{
  "has_subscription": true,
  "subscription": {
    "product_id": "sniffyearly",
    "status": "active",
    "expiration_date": "2026-01-15T10:30:00Z"
  },
  "user_role": "premium"
}
```

### 3. Restore Purchases (POST `/api/v1/subscriptions/restore`)

Restore user's purchases from receipt.

**Request:** Same as verify endpoint

### 4. Webhook Endpoint (POST `/api/v1/subscriptions/webhook`)

Handles App Store Server Notifications. This endpoint should NOT be called by your app - only by Apple's servers.

## 🔐 Security Considerations

### Receipt Verification Flow

1. **Client gets receipt** from StoreKit
2. **Client sends receipt** to your backend
3. **Backend verifies** with Apple's servers
4. **Backend updates** user subscription status
5. **Backend returns** confirmation to client

### Why Server-Side Verification?

- **Security**: Prevents users from faking subscriptions
- **Reliability**: Single source of truth
- **Business Logic**: Centralized subscription management
- **Apple Requirements**: Required for proper subscription handling

## 📱 iOS Integration

Update your iOS `SubscriptionViewModel.swift`:

```swift
private func syncSubscriptionWithBackend() async {
    guard let receiptURL = Bundle.main.appStoreReceiptURL,
          let receiptData = try? Data(contentsOf: receiptURL) else {
        logger.error("No receipt found")
        return
    }
    
    let receiptBase64 = receiptData.base64EncodedString()
    
    // Call your backend API
    let endpoint = "\(APIConfig.baseURL)/subscriptions/verify"
    
    var request = URLRequest(url: URL(string: endpoint)!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
    
    let body = [
        "receipt_data": receiptBase64,
        "exclude_old_transactions": true
    ]
    
    request.httpBody = try? JSONEncoder().encode(body)
    
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            logger.error("Backend verification failed")
            return
        }
        
        logger.info("Subscription synced with backend")
    } catch {
        logger.error("Error syncing with backend: \(error)")
    }
}
```

## 🔔 App Store Server Notifications

### Setup in App Store Connect

1. Go to App Store Connect → Your App → App Information
2. Scroll to "App Store Server Notifications"
3. Enter your webhook URL: `https://your-api.com/api/v1/subscriptions/webhook`
4. Apple will send test notifications to verify

### Notification Types Handled

- `DID_RENEW`: Subscription renewed successfully
- `DID_CHANGE_RENEWAL_STATUS`: User enabled/disabled auto-renew
- `EXPIRED`: Subscription expired
- `GRACE_PERIOD_EXPIRED`: Grace period ended
- `REFUND`: User received refund
- `REVOKE`: Subscription revoked by Apple

## 🧪 Testing

### Local Testing

1. **StoreKit Configuration**: Use `Configuration.storekit` for local testing
2. **Sandbox Accounts**: Create sandbox testers in App Store Connect
3. **Receipt Verification**: Backend automatically switches to sandbox when needed

### Test Flow

```bash
# 1. Make a test purchase in iOS app
# 2. Check logs for receipt verification
# 3. Verify in database

# Check subscription was created
SELECT * FROM subscriptions WHERE user_id = 'your_user_id';

# Check user role was updated
SELECT id, email, role FROM auth.users WHERE id = 'your_user_id';
```

### Testing Webhook

Use ngrok to expose your local server:

```bash
ngrok http 8000
# Copy the HTTPS URL to App Store Connect webhook settings
```

## 🔄 User Role Management

The system automatically manages user roles:

| Subscription Status | User Role |
|-------------------|-----------|
| `active` | `premium` |
| `grace_period` | `premium` |
| `billing_retry` | `premium` |
| `expired` | `free` |
| `cancelled` | `free` (after expiration) |
| `revoked` | `free` |

## 📊 Monitoring

### Important Queries

```sql
-- Active subscriptions count
SELECT COUNT(*) FROM subscriptions WHERE status = 'active';

-- Expiring soon (next 7 days)
SELECT COUNT(*) FROM subscriptions 
WHERE status = 'active' 
AND expiration_date < NOW() + INTERVAL '7 days';

-- Cancelled subscriptions (auto-renew off)
SELECT COUNT(*) FROM subscriptions 
WHERE status = 'active' 
AND auto_renew = false;

-- Revenue by tier
SELECT tier, COUNT(*) FROM subscriptions 
WHERE status = 'active' 
GROUP BY tier;
```

## 🚨 Error Handling

### Common Receipt Verification Status Codes

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success | Proceed |
| 21000 | Bad request | Check receipt format |
| 21002 | Invalid receipt | Receipt is corrupted |
| 21003 | Authentication failed | Check shared secret |
| 21007 | Sandbox receipt sent to production | Retry with sandbox URL |
| 21008 | Production receipt sent to sandbox | Retry with production URL |

## 📝 Next Steps

1. ✅ Apply database schema
2. ✅ Add environment variables
3. ✅ Update iOS app to call backend API
4. ✅ Configure App Store webhook
5. ✅ Test with sandbox account
6. ✅ Monitor subscription metrics

## 🔗 Resources

- [Apple Receipt Validation](https://developer.apple.com/documentation/appstorereceipts/verifyreceipt)
- [App Store Server Notifications](https://developer.apple.com/documentation/appstoreservernotifications)
- [StoreKit 2 Documentation](https://developer.apple.com/documentation/storekit)

## 🆘 Troubleshooting

### Issue: Receipt verification fails with status 21002

**Solution**: Receipt data might be corrupted. Ensure you're properly base64 encoding the receipt.

### Issue: User role not updating

**Solution**: Check that the subscription service has permission to update the users table. Verify RLS policies.

### Issue: Webhook not receiving notifications

**Solution**: 
1. Verify webhook URL is HTTPS
2. Check that endpoint returns 200 status
3. Test with ngrok locally
4. Check App Store Connect webhook configuration

---

**Last Updated**: November 8, 2025

