# ✅ Subscription Implementation Checklist

## Server-Side Changes Needed

### 1. Database Setup
- [ ] Run `database_schemas/04_subscriptions_table.sql` in Supabase
- [ ] Verify table created: `SELECT * FROM subscriptions LIMIT 1;`

### 2. Environment Variables
- [ ] Add `APPLE_SHARED_SECRET` to `.env` file
- [ ] Get secret from App Store Connect → In-App Purchases → App-Specific Shared Secret

### 3. Register API Router
- [ ] Add to `server/main.py`:
```python
from app.api.v1.subscriptions.router import router as subscriptions_router

app.include_router(
    subscriptions_router,
    prefix="/api/v1/subscriptions",
    tags=["subscriptions"]
)
```

### 4. Update iOS Client
- [ ] Replace `syncSubscriptionWithBackend()` in `SubscriptionViewModel.swift` (see SUBSCRIPTION_IMPLEMENTATION_SUMMARY.md)
- [ ] Ensure `APIConfig.baseURL` points to your server

### 5. Deploy & Test
- [ ] Deploy backend changes
- [ ] Test purchase in iOS simulator
- [ ] Verify subscription created in database
- [ ] Verify user role updated to "premium"

### 6. Production Setup (After Testing)
- [ ] Configure webhook in App Store Connect
- [ ] Add webhook URL: `https://your-api.com/api/v1/subscriptions/webhook`
- [ ] Test with sandbox account on real device
- [ ] Monitor logs and database

## Quick Test Commands

```sql
-- Check if subscription was created
SELECT * FROM subscriptions ORDER BY created_at DESC LIMIT 1;

-- Check user role
SELECT id, email, role FROM auth.users WHERE id = 'YOUR_USER_ID';

-- Count active subscriptions
SELECT COUNT(*) FROM subscriptions WHERE status = 'active';
```

## Files Created

✅ `server/app/models/subscription.py` - Subscription models
✅ `server/app/services/subscription_service.py` - Receipt verification
✅ `server/app/api/v1/subscriptions/router.py` - API endpoints
✅ `server/database_schemas/04_subscriptions_table.sql` - Database schema
✅ `server/SUBSCRIPTION_SETUP.md` - Detailed setup guide
✅ `SUBSCRIPTION_IMPLEMENTATION_SUMMARY.md` - Complete overview

## API Endpoints Available

- `POST /api/v1/subscriptions/verify` - Verify receipt after purchase
- `GET /api/v1/subscriptions/status` - Get user's subscription status
- `POST /api/v1/subscriptions/restore` - Restore purchases
- `POST /api/v1/subscriptions/webhook` - Handle Apple notifications

## Estimated Time: 20 minutes

---

**Questions?** See `SUBSCRIPTION_IMPLEMENTATION_SUMMARY.md` for complete details.

