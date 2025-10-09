# Railway Deployment Guide

## Issues Fixed

### 1. ✅ Correct Builder Configuration
**Problem:** Configuration needed to use Railway's current builder
**Solution:** Using `"RAILPACK"` which is Railway's modern builder (NIXPACKS is deprecated)

### 2. ✅ Wrong Health Check Path
**Problem:** `railway.toml` had healthcheck path set to `/api/v1/health` but your endpoint is at `/health`
**Solution:** Updated to correct path `/health`

### 3. ✅ TrustedHostMiddleware Blocking Health Checks
**Problem:** `allowed_hosts` was restricted to `["localhost", "127.0.0.1"]`, blocking Railway's infrastructure requests
**Solution:** Updated to allow all hosts (`["*"]`) in production/staging environments

### 4. ✅ Database Dependency in Health Check
**Problem:** Health check endpoint called database which could fail during startup
**Solution:** Simplified health check to return immediate response without database dependency

### 5. ✅ Extended Health Check Timeout
**Problem:** 100 seconds might not be enough for cold starts
**Solution:** Increased to 300 seconds (5 minutes) for reliable health checks

## Railway Configuration Files

You have two configuration files (Railway supports both):

### railway.toml (Preferred)
```toml
[build]
builder = "RAILPACK"
buildCommand = "pip install -r requirements.txt"

[deploy]
startCommand = "uvicorn main:app --host 0.0.0.0 --port $PORT"
healthcheckPath = "/health"
healthcheckTimeout = 300
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 10

[env]
PYTHONUNBUFFERED = "1"
PYTHONDONTWRITEBYTECODE = "1"
ENVIRONMENT = "production"
```

### railway.json (Alternative)
Same configuration in JSON format. You can delete one if you prefer.

## Required Environment Variables in Railway

Make sure these are set in your Railway project settings:

### Essential Variables
```
ENVIRONMENT=production
SUPABASE_URL=<your-supabase-url>
SUPABASE_KEY=<your-supabase-anon-key>
SUPABASE_SERVICE_ROLE_KEY=<your-service-role-key>
SUPABASE_JWT_SECRET=<your-jwt-secret>
SECRET_KEY=<generate-a-secure-32-char-key>
DATABASE_URL=<your-database-connection-string>
```

### APNs Configuration
```
APNS_URL=https://api.push.apple.com
APNS_KEY_ID=<your-key-id>
APNS_TEAM_ID=<your-team-id>
APNS_BUNDLE_ID=<your-bundle-id>
APNS_PRIVATE_KEY=<your-p8-key-content>
```

### Optional Configuration
```
ALLOWED_ORIGINS_STR=https://your-frontend.com,https://app.your-domain.com
ALLOWED_HOSTS_STR=*
RATE_LIMIT_PER_MINUTE=100
DATABASE_POOL_SIZE=20
LOG_LEVEL=INFO
```

## Health Check Endpoints

Your API now has multiple health check endpoints:

1. **`/health`** - Simple, fast health check (used by Railway)
   - No database dependency
   - Returns immediately
   - Ideal for infrastructure health checks

2. **`/api/v1/monitoring/health`** - Detailed health check
   - Includes database connection status
   - More comprehensive monitoring
   - Use for application-level health monitoring

3. **`/`** - Root endpoint
   - Simple status check
   - Returns API version

## Deployment Steps

1. **Push your changes to your repository**
   ```bash
   git add .
   git commit -m "Fix Railway deployment configuration"
   git push origin main
   ```

2. **In Railway Dashboard:**
   - Ensure all environment variables are set
   - Trigger a new deployment
   - Monitor the deployment logs

3. **Verify Deployment:**
   - Check health endpoint: `https://your-railway-url.railway.app/health`
   - Should return: `{"status": "healthy", "version": "1.0.0", "service": "SniffTest API"}`

## Troubleshooting

### If Health Check Still Fails

1. **Check Railway Logs**
   ```bash
   railway logs
   ```

2. **Verify Environment Variables**
   - Ensure `ENVIRONMENT=production` is set
   - Check all required Supabase variables are present

3. **Test Health Endpoint Manually**
   ```bash
   curl https://your-railway-url.railway.app/health
   ```

4. **Check for Missing Dependencies**
   - Verify `requirements.txt` includes all packages
   - Ensure no import errors during startup

### Common Issues

**Issue:** "Host validation failed"
**Solution:** Ensure `ENVIRONMENT=production` is set in Railway

**Issue:** "Health check timeout"
**Solution:** Check application startup logs for errors, especially database connection issues

**Issue:** "Module not found"
**Solution:** Add missing package to `requirements.txt` and redeploy

## Security Considerations

### Host Restrictions
- Development: Restricted to localhost
- Production/Staging: Allows all hosts for Railway compatibility
- Override with `ALLOWED_HOSTS_STR` environment variable for stricter control

### CORS Configuration
- Update `ALLOWED_ORIGINS_STR` with your actual frontend domains
- Never use `*` in production CORS settings

### Database Security
- Use connection pooling (configured via `DATABASE_POOL_SIZE`)
- Enable SSL for database connections in production
- Set appropriate timeouts (`DATABASE_TIMEOUT`)

## Monitoring

### Health Check Response
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "service": "SniffTest API"
}
```

### For Detailed Monitoring
Use `/api/v1/monitoring/health` endpoint which includes:
- Database connection status
- Connection pool statistics
- Service health metrics

## Next Steps

1. ✅ Deploy to Railway with fixed configuration
2. ⚠️ Update your frontend to use the Railway URL
3. ⚠️ Set up custom domain in Railway (optional)
4. ⚠️ Configure SSL certificates (Railway handles this automatically)
5. ⚠️ Set up monitoring and alerts in Railway dashboard
6. ⚠️ Review and update CORS allowed origins for production

## Additional Resources

- [Railway Docs](https://docs.railway.app/)
- [FastAPI Deployment](https://fastapi.tiangolo.com/deployment/)
- [Railpack Introduction](https://blog.railway.com/p/introducing-railpack)
- [Railway Help Station](https://help.railway.com/)

