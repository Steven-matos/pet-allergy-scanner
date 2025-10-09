# Healthcheck Disabled - Debugging Guide

## What Was Changed

✅ **Healthcheck is now disabled** to allow you to see the actual startup logs.

### Files Updated:
- `railway.toml` - Commented out healthcheck settings
- `railway.json` - Removed healthcheck settings

## Why This Helps

The healthcheck was **hiding the real problem**. With healthcheck disabled:
- ✅ Railway will deploy even if the app isn't responding
- ✅ You can see the **actual startup logs** and error messages
- ✅ You can identify why the app isn't starting

## Next Steps

### 1. Deploy Without Healthcheck

```bash
git add .
git commit -m "Disable healthcheck to debug startup issues"
git push origin main
```

### 2. View Runtime Logs Immediately

```bash
railway logs --follow
```

Or in Railway Dashboard:
- Go to your deployment
- Click **Logs** tab
- Look for ERROR messages after the build completes

### 3. Look For These Common Issues

**Missing Environment Variables:**
```
❌ Missing Required Environment Variables
  ❌ SUPABASE_URL
  ❌ SECRET_KEY
```
→ **Fix:** Set all required variables in Railway Settings → Variables

**Import Errors:**
```
ModuleNotFoundError: No module named 'xxx'
```
→ **Fix:** Add missing package to `requirements.txt`

**Configuration Errors:**
```
ValidationError: SECRET_KEY must be at least 32 characters
```
→ **Fix:** Generate proper SECRET_KEY with `python3 test_config.py --generate-key`

**Port Binding Issues:**
```
OSError: [Errno 98] Address already in use
```
→ **Fix:** Make sure using `$PORT` environment variable (already configured)

**Pydantic/Settings Errors:**
```
pydantic_core._pydantic_core.ValidationError
```
→ **Fix:** Check all required fields in Settings class have values

### 4. Test If App Is Actually Running

Even with healthcheck disabled, test manually:

```bash
# Get your Railway URL from dashboard
curl https://your-app.railway.app/health

# Or test root
curl https://your-app.railway.app/
```

### 5. Once Working, Re-enable Healthcheck

After fixing the startup issues, uncomment in `railway.toml`:

```toml
[deploy]
startCommand = "python3 railway_start.py"
healthcheckPath = "/health"         # Uncomment these
healthcheckTimeout = 300            # Uncomment these
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 3
```

## What Logs Should Look Like (Success)

```
🚀 Starting SniffTest API on Railway
📡 Port: 8080
🌍 Environment: production
✅ All required environment variables present
✅ Settings loaded successfully
📦 Loading uvicorn...
🎬 Starting uvicorn server on 0.0.0.0:8080
============================================================
INFO:     Started server process [1]
INFO:     Waiting for application startup.
✅ Database connection established
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8080
```

## What Logs Look Like (Failure)

### Example: Missing Environment Variables
```
🚀 Starting SniffTest API on Railway
📡 Port: 8080
🌍 Environment: production
🔍 Validating configuration...
❌ Missing Required Environment Variables
  ❌ SECRET_KEY
  ❌ SUPABASE_URL
```

### Example: Import Error
```
Traceback (most recent call last):
  File "railway_start.py", line X
    from app.core.config import settings
ModuleNotFoundError: No module named 'app'
```

### Example: Settings Validation Error
```
pydantic_core._pydantic_core.ValidationError: 1 validation error for Settings
SECRET_KEY
  Field required [type=missing, input_value={...}, input_type=dict]
```

## Quick Debug Commands

```bash
# View last 100 log lines
railway logs --tail 100

# Follow logs in real-time
railway logs --follow

# Check environment variables are set
railway variables

# Force redeploy
railway up

# Get service info
railway status
```

## Most Likely Issues (Based on Your Logs)

Your build is **succeeding** (completed in 10.88s), so the problem is **runtime**.

Most likely causes:
1. ❌ Missing environment variables in Railway
2. ❌ App is starting but crashing immediately
3. ❌ Port binding issue
4. ❌ Database connection blocking startup (less likely now with fixes)

## The Real Fix

**Check Railway Dashboard → Settings → Variables**

You MUST have these 7 variables set:
- ✅ ENVIRONMENT
- ✅ SECRET_KEY
- ✅ SUPABASE_URL
- ✅ SUPABASE_KEY
- ✅ SUPABASE_SERVICE_ROLE_KEY
- ✅ SUPABASE_JWT_SECRET
- ✅ DATABASE_URL

Missing even ONE will cause immediate failure.

## After You See the Logs

Share the **first 50 lines after "Starting Container"** and I can help identify the exact issue.

---

**Remember:** Disabling healthcheck doesn't fix the problem, it just lets you see what the problem actually is! 🔍

