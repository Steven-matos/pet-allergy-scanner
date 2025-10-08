# 🌐 Railway Web UI Deployment - Step by Step

## 📋 Prerequisites

Before starting, generate your environment variables:

```bash
cd server
python3 generate-railway-vars.py
```

Keep this terminal window open - you'll copy from it in Step 5.

---

## 🚀 Step-by-Step Deployment

### Step 1: Login to Railway

1. Go to **https://railway.app**
2. Click **"Login"** (top right)
3. Sign in with:
   - GitHub (recommended)
   - Google
   - Email

---

### Step 2: Open Your Project

1. You should see your project: **"snifftest-api"**
2. Click on it to open

**If you don't see the project:**
- Click **"New Project"**
- Select **"Empty Project"**
- Name it: `snifftest-api`

---

### Step 3: Create a Service

1. Inside your project, click the **"+ New"** button
2. Select **"Empty Service"**
3. Name it: `backend` or `api` (your choice)
4. Click **"Add Service"**

You'll now see your new service card in the project.

---

### Step 4: Configure Service Settings

1. Click on your **service card** to open it
2. Go to the **"Settings"** tab (left sidebar)

**Configure these settings:**

#### Build Settings
- **Builder**: Should auto-detect or use your `railway.toml`
- **Root Directory**: Leave empty (or `/server` if Railway can't find your files)
- **Watch Paths**: Leave default

#### Deploy Settings
- **Start Command**: Already configured in `Procfile`
  - Should show: `uvicorn main:app --host 0.0.0.0 --port $PORT`
- **Custom Build Command**: `pip install -r requirements.txt`

#### Health Check
- **Health Check Path**: `/health`
- **Health Check Timeout**: `100` seconds

Click **"Save"** if you made any changes.

---

### Step 5: Set Environment Variables

1. Still in your service, click **"Variables"** tab (left sidebar)
2. Click **"RAW Editor"** button (top right)
3. **Go back to your terminal** where you ran `generate-railway-vars.py`
4. **Copy the OPTION 2 output** (everything between the dashes):

```
SUPABASE_URL=https://...
SUPABASE_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...
... (all variables)
```

5. **Paste into the Raw Editor** in Railway
6. Click **"Update Variables"** button
7. Confirm the changes

**Variables should now appear in the list** ✅

---

### Step 6: Connect to GitHub (Optional but Recommended)

This enables auto-deploy on every push.

1. In service settings, scroll to **"Source"** section
2. Click **"Connect to GitHub"**
3. Authorize Railway to access your repo
4. Select repository: `pet-allergy-scanner`
5. Select branch: `main`
6. **Root Directory**: `server`
7. Click **"Connect"**

**Skip this if you prefer manual deployments via CLI**

---

### Step 7: Deploy

#### Option A: From Web UI
1. Go to **"Deployments"** tab
2. Click **"Deploy"** button (top right)
3. Deployment will start automatically

#### Option B: From CLI
```bash
cd server
railway service  # Verify service is linked
railway up       # Deploy
```

**Watch the deployment logs in real-time!**

---

### Step 8: Monitor Deployment

1. In **"Deployments"** tab, watch the build logs
2. You'll see:
   - ⚙️ Building... (installing dependencies)
   - 🚀 Deploying...
   - ✅ Success! (with a green checkmark)

**Build takes ~2-5 minutes for first deployment**

---

### Step 9: Get Your Public URL

1. Go to **"Settings"** tab
2. Scroll to **"Networking"** section
3. Under **"Public Networking"**, click **"Generate Domain"**
4. Railway will create a URL like:
   ```
   https://backend-production-xxxx.up.railway.app
   ```
5. **Copy this URL** - you'll need it!

**OR from CLI:**
```bash
railway domain
```

---

### Step 10: Update CORS Settings

**Important!** Update your CORS with the actual Railway URL:

1. Go back to **"Variables"** tab
2. Add these two new variables (click "+ New Variable"):

**Variable 1:**
- **Key**: `ALLOWED_ORIGINS_STR`
- **Value**: `https://YOUR-URL.up.railway.app,https://api.petallergyscanner.com,capacitor://localhost,sniffsafe://`
  - Replace `YOUR-URL` with your actual Railway domain

**Variable 2:**
- **Key**: `ALLOWED_HOSTS_STR`  
- **Value**: `YOUR-URL.up.railway.app,api.petallergyscanner.com`
  - Replace `YOUR-URL` with your actual Railway domain

3. Click **"Save"** - this will trigger a redeploy

---

### Step 11: Verify Deployment

#### Test Health Endpoint

Open in browser or use curl:
```bash
curl https://YOUR-URL.up.railway.app/health
```

**Expected response:**
```json
{
  "status": "healthy",
  "database": {
    "status": "connected"
  },
  "version": "1.0.0"
}
```

#### Test Root Endpoint

```bash
curl https://YOUR-URL.up.railway.app/
```

**Expected response:**
```json
{
  "message": "SniffTest API is running",
  "version": "1.0.0"
}
```

✅ **If both work, you're live!**

---

### Step 12: Update iOS App

Update your iOS app to use the production API:

**File**: `SniffTest/Shared/Services/APIService.swift` (or similar)

```swift
// Change from:
private let baseURL = "http://localhost:8000"

// To your Railway URL:
private let baseURL = "https://YOUR-URL.up.railway.app"
```

Rebuild and test your iOS app!

---

## 🔍 Monitoring & Logs

### View Logs

1. Go to **"Observability"** or **"Deployments"** tab
2. Click on your deployment
3. View real-time logs

**From CLI:**
```bash
railway logs
railway logs --recent  # Recent logs only
```

### Check Resource Usage

1. Go to **"Metrics"** tab
2. View:
   - CPU usage
   - Memory usage
   - Request count
   - Response times

---

## 🐛 Troubleshooting

### Deployment Failed?

**Check build logs:**
1. Go to **"Deployments"** tab
2. Click on failed deployment
3. Read the error logs

**Common issues:**

#### Missing Dependencies
```
Error: No module named 'fastapi'
```
**Fix**: Ensure `requirements.txt` is in root of `/server`

#### Port Binding Error
```
Error: Address already in use
```
**Fix**: Ensure you're using `$PORT` variable in start command

#### Database Connection Failed
```
Error: Could not connect to database
```
**Fix**: Verify `DATABASE_URL` variable is set correctly

### CORS Errors?

If your iOS app gets CORS errors:

1. Go to **Variables** tab
2. Check `ALLOWED_ORIGINS_STR` includes your Railway domain
3. Make sure it starts with `https://` (not `http://`)
4. No trailing slashes!

### Environment Variables Not Loading?

1. Go to **Variables** tab
2. Click each variable to verify it saved correctly
3. Multi-line variables (like `APNS_PRIVATE_KEY`) should have `\n` for newlines
4. Re-deploy after fixing: Click **"Deploy"** in Deployments tab

---

## 💰 Cost Monitoring

### Check Usage

1. Click on your **profile** (top right)
2. Go to **"Usage"**
3. View current month's usage

### Set Spending Limit

1. Go to **"Account Settings"**
2. Click **"Billing"**
3. Set a monthly spending limit
4. Enable email alerts

**Typical costs:**
- Starter: $5-10/month
- Production (low traffic): $10-20/month

---

## 🔄 Making Updates

### After Code Changes

**If connected to GitHub:**
1. Push to `main` branch
2. Railway auto-deploys
3. Watch logs in Deployments tab

**Manual deployment:**
```bash
cd server
railway up
```

### Rollback Deployment

1. Go to **"Deployments"** tab
2. Find previous successful deployment
3. Click **"⋯"** menu
4. Select **"Redeploy"**

---

## 🎯 Quick Reference

### Essential URLs
- **Railway Dashboard**: https://railway.app
- **Your Project**: https://railway.app/project/[your-project-id]
- **API URL**: https://your-service.up.railway.app

### Common Tasks

| Task | Location |
|------|----------|
| View logs | Deployments → Click deployment |
| Add variables | Variables tab → New Variable |
| Redeploy | Deployments → Deploy button |
| Change settings | Settings tab |
| View metrics | Metrics tab |
| Get domain | Settings → Networking |

---

## ✅ Deployment Complete!

Your FastAPI backend is now live on Railway! 🎉

**Next steps:**
1. ✅ Test all API endpoints
2. ✅ Update iOS app with production URL
3. ✅ Switch APNs to production (already done via variables)
4. ✅ Monitor logs for any errors
5. ✅ Set up custom domain (optional)

**Need help?**
- Railway Docs: https://docs.railway.app
- Railway Discord: https://discord.gg/railway
- Check deployment logs for errors
