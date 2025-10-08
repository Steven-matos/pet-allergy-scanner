# ⚠️ Railway Setup Script Fix

## Problem
The `railway-setup.sh` script had issues with:
1. Parsing multi-line environment variables (APNs private key)
2. Railway CLI command syntax compatibility

## ✅ Solutions

### Option 1: Use Python Script (Recommended)
This generates commands you can copy and paste:

```bash
cd server
python3 generate-railway-vars.py
```

This will output:
- **Option 1**: CLI commands to copy-paste one by one
- **Option 2**: Variables in RAW format for Railway Web UI

### Option 2: Use Railway Web UI (Easiest)

1. **Create your Railway project**:
   ```bash
   railway login
   railway init
   ```

2. **Go to Railway Dashboard**:
   - Open https://railway.app
   - Open your project
   - Click on your service
   - Go to **Variables** tab
   - Click **RAW Editor**

3. **Copy the variables**:
   Run the generator and copy the OPTION 2 output:
   ```bash
   python3 generate-railway-vars.py
   ```
   
   Copy everything between the dashes (starting from `SUPABASE_URL=...`)

4. **Paste into Railway**:
   - Paste all variables in the RAW Editor
   - Click **Save**

5. **Add CORS variables** (after deployment):
   ```
   ALLOWED_ORIGINS_STR=https://YOUR-APP.up.railway.app,https://api.petallergyscanner.com,capacitor://localhost,sniffsafe://
   ALLOWED_HOSTS_STR=YOUR-APP.up.railway.app,api.petallergyscanner.com
   ```

### Option 3: Fixed Bash Script

The `railway-setup.sh` has been updated with better parsing. Try it again:

```bash
./railway-setup.sh
```

If it still fails, use Options 1 or 2 above.

## 🚀 Deploy After Setting Variables

Once variables are set (using any method):

```bash
railway up
```

Then get your URL:

```bash
railway domain
```

## 📋 Post-Deployment Checklist

1. **Get your Railway URL**
2. **Update CORS settings** with your actual Railway URL
3. **Test health endpoint**: `curl https://YOUR-URL/health`
4. **Update iOS app** with production API URL
5. **Monitor logs**: `railway logs`

## 💡 Why Use Web UI?

The Railway Web UI is the most reliable method because:
- ✅ No CLI version compatibility issues
- ✅ Handles multi-line values automatically
- ✅ Visual confirmation of all variables
- ✅ Easy to edit later
- ✅ Less error-prone

## Need Help?

1. Check `QUICK_START.md` for deployment guide
2. Check `RAILWAY_DEPLOYMENT.md` for detailed instructions
3. Run `python3 check-deployment-ready.py` to verify setup
