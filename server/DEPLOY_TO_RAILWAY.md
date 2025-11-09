# Deploy to Railway - Healthcheck Fix Applied

## ✅ Problem Fixed
Railway healthchecks were failing because database initialization was **blocking server startup**. The server now starts immediately and database connection happens in the background.

## 🚀 Changes Made

### 1. Non-Blocking Database Initialization (`app/database.py`)
- ✅ Server starts immediately without waiting for database
- ✅ Database connection tested in background task
- ✅ Uses `asyncio.to_thread()` for non-blocking Supabase calls
- ✅ Proper timeouts (5s per attempt, 3 retries)

### 2. Railway Configuration (`railway.toml`)
- ✅ `healthcheckTimeout`: 300 seconds (5 minutes)
- ✅ `restartPolicyMaxRetries`: 10 retries
- ✅ Health path: `/health`

### 3. Test Script (`test_health_endpoint.py`)
- ✅ Verifies health endpoint responds in < 2 seconds
- ✅ Tests both `/health` and `/` endpoints
- ✅ Can be run before deploying

## 📋 Pre-Deployment Checklist

### Required Environment Variables in Railway
Ensure these are set in Railway Dashboard → Variables:

```
✅ SUPABASE_URL
✅ SUPABASE_KEY  
✅ SUPABASE_SERVICE_ROLE_KEY
✅ SUPABASE_JWT_SECRET
✅ SECRET_KEY (32+ characters)
✅ DATABASE_URL
✅ ENVIRONMENT=production
```

### Optional but Recommended
```
ALLOWED_ORIGINS (comma-separated)
ALLOWED_HOSTS (comma-separated)  
REVENUECAT_PUBLIC_KEY
REVENUECAT_SECRET_KEY
APNS_KEY_ID
APNS_TEAM_ID
```

## 🧪 Test Before Deploying

Run local test:
```bash
cd server
python3 test_health_endpoint.py
```

Expected output:
```
✅ PASS: Fast response time (0.00s)
✅ All health checks passed!
```

## 📦 Deploy to Railway

### Option 1: Git Push (Recommended)
```bash
# Commit changes
git add server/app/database.py server/railway.toml
git commit -m "Fix Railway healthcheck - non-blocking database init"
git push origin main

# Railway will auto-deploy
```

### Option 2: Railway CLI
```bash
railway up
```

## 🔍 Monitor Deployment

### Watch Build Logs
```bash
railway logs
```

### Expected Log Sequence
```
🚀 Starting SniffTest API on Railway
📡 Port: XXXX
🌍 Environment: production
🔍 Validating configuration...
✅ All required environment variables present
⚙️  Loading application settings...
✅ Settings loaded successfully
📦 Loading uvicorn...
🎬 Starting uvicorn server on 0.0.0.0:XXXX
...
Initializing database clients...
✅ Database clients created
Testing database connection (attempt 1/3)...
✅ Database connection verified successfully
```

### Expected Healthcheck Results
```
====================
Starting Healthcheck
====================
Path: /health
Retry window: 5m0s

✅ Attempt #1 succeeded
Healthcheck passed!
1/1 replicas healthy
```

## 🐛 Troubleshooting

### If Healthcheck Still Fails

1. **Check Environment Variables**
   ```bash
   railway variables
   ```
   Verify all required variables are set

2. **Check Logs for Errors**
   ```bash
   railway logs --follow
   ```
   Look for:
   - Missing environment variables
   - Configuration validation errors
   - Port binding issues

3. **Verify Database Connection**
   Look for these in logs:
   ```
   ✅ Database clients created
   ✅ Database connection verified
   ```
   
   If you see:
   ```
   ⚠️  Database connection test failed
   ```
   Check Supabase credentials and network connectivity

4. **Test Health Endpoint Manually**
   Once deployed:
   ```bash
   curl https://your-app.up.railway.app/health
   ```
   Should return:
   ```json
   {"status":"healthy","version":"1.0.0","service":"SniffTest API"}
   ```

### If Server Crashes

Check for:
- **SECRET_KEY too short**: Must be 32+ characters
- **Invalid SUPABASE_URL**: Check for typos
- **Database timeout**: Supabase may be down or blocked
- **Port not set**: Railway sets PORT automatically

## 🎯 Success Indicators

✅ Deployment succeeds
✅ Healthcheck passes on first attempt  
✅ Logs show "Database connection verified"
✅ API responds at your Railway URL
✅ No "service unavailable" errors

## 📚 Related Documentation

- `RAILWAY_HEALTHCHECK_FIX.md` - Technical details of the fix
- `server/README.md` - Full API documentation
- `railway.toml` - Railway configuration
- Railway Docs: https://docs.railway.app/

## 🔄 Rollback Plan

If deployment fails, rollback:
```bash
git revert HEAD
git push origin main
```

Railway will automatically deploy the previous version.

## ✨ What's New

- 🚀 **Instant startup**: Server responds in < 1 second
- 🔄 **Non-blocking**: Database doesn't block healthchecks  
- 🛡️ **Fault-tolerant**: Works even if database is temporarily down
- 📊 **Better observability**: Clear logging of startup stages
- ⚡ **Faster deploys**: No more 100s healthcheck timeouts

---

**Ready to deploy?** Just push to main and Railway will handle the rest! 🚀

