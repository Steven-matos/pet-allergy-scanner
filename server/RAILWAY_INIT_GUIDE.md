# 🚂 Railway Initialization - Step by Step

## Issue You Encountered

You got **"No service linked"** errors because Railway needs to be initialized first before setting variables.

---

## ✅ Complete Setup (Step by Step)

### Step 1: Login to Railway

```bash
cd server
railway login
```

This will open your browser to authenticate.

---

### Step 2: Initialize Railway Project

```bash
railway init
```

**You'll be prompted with options:**

#### Option A: Create Empty Project (Recommended)

```
? Enter project name (pet-allergy-scanner-api): [Enter your name]
? Select a team: [Select your team or personal]
✅ Created project: pet-allergy-scanner-api
```

Railway will automatically create a service for you.

#### Option B: Link Existing Project

If you already created a project in Railway dashboard:
```
? Link to existing project? Yes
? Select a project: [Choose your project]
```

---

### Step 3: Verify Service is Linked

```bash
railway service
```

**Expected output:**
```
Service: [your-service-id]
```

If you see this, you're good! ✅

**If you see "No service linked":**
```bash
# List available services
railway service list

# Link to a service
railway service [service-name-or-id]
```

---

### Step 4: Set Environment Variables

Now you can run the setup script:

```bash
./railway-setup.sh
```

**OR use the Python generator + Web UI:**

```bash
# Generate variables
python3 generate-railway-vars.py

# Copy OPTION 2 output
# Go to Railway dashboard → Variables tab → Raw Editor
# Paste and save
```

---

### Step 5: Deploy

```bash
railway up
```

Wait for deployment to complete...

---

### Step 6: Get Your URL

```bash
railway domain
```

Example output: `https://pet-allergy-scanner-production.up.railway.app`

---

### Step 7: Update CORS Variables

```bash
# Replace YOUR-URL with your actual Railway URL
railway variables --set "ALLOWED_ORIGINS_STR=https://YOUR-URL.up.railway.app,https://api.petallergyscanner.com,capacitor://localhost,sniffsafe://"

railway variables --set "ALLOWED_HOSTS_STR=YOUR-URL.up.railway.app,api.petallergyscanner.com"
```

---

### Step 8: Verify Deployment

```bash
# Check logs
railway logs

# Test health endpoint
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

---

## 🎯 Quick Reference

```bash
# Full workflow
cd server
railway login              # 1. Login
railway init              # 2. Create project & service
railway service           # 3. Verify service linked
./railway-setup.sh        # 4. Set variables
railway up                # 5. Deploy
railway domain            # 6. Get URL
# 7. Update CORS with your URL
# 8. Test!
```

---

## 🔍 Troubleshooting

### "No service linked" After Init

```bash
# Check if project exists
railway status

# If no project, run init again
railway init

# If project exists but no service, list services
railway service list

# Create a new service if needed
railway service create
```

### Multiple Services in Project

If you have multiple services (e.g., frontend + backend):

```bash
# List all services
railway service list

# Link to specific service
railway service <service-name>

# Set variables for specific service
railway variables --set "KEY=value" --service <service-name>
```

### Prefer Web UI?

If CLI is giving you trouble:

1. Go to https://railway.app
2. Create a new project
3. Click "Empty Project"
4. Click "New" → "Empty Service"
5. In Settings → set root directory to `/server` (if needed)
6. Go to Variables tab → Raw Editor
7. Paste variables from `python3 generate-railway-vars.py`
8. In Deployments tab → click "Deploy"

---

## 💡 Pro Tips

### Skip Auto-Deploy When Setting Variables

```bash
railway variables --set "KEY=value" --skip-deploys
# Set all variables first, then deploy manually
railway up
```

### View Current Variables

```bash
# Pretty format
railway variables

# Key-value format
railway variables --kv

# JSON format
railway variables --json
```

### Check Service Info

```bash
# View service details
railway service

# View project status
railway status

# Open dashboard
railway open
```

---

## 🚀 You're Ready!

Once you complete Step 1-3 above, run:

```bash
./railway-setup.sh
```

The script will now check that you're properly set up before trying to set variables.
