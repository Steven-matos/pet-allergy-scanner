# Railway Healthcheck Fix

## Problem
Railway healthchecks were failing with "service unavailable" errors because the server wasn't starting fast enough. The healthcheck endpoint `/health` was timing out after 100 seconds.

## Root Cause
The database initialization in `app/database.py` was **blocking the server startup**:

1. **Synchronous Supabase calls**: The `supabase.table().execute()` calls are synchronous and can take 10+ seconds to timeout
2. **Retry logic**: With 2 retries and 2-second delays between attempts, database connection could take 20+ seconds
3. **Server not listening**: Uvicorn doesn't start listening on the PORT until the lifespan function completes
4. **Healthcheck starts immediately**: Railway begins healthchecks as soon as the container starts, but server isn't ready yet

### Timeline
```
0s:   Container starts, Railway begins healthchecks
0-20s: Database init blocks (sync calls with retries)
20s:  Server FINALLY starts listening on PORT
20-100s: Healthchecks fail because server wasn't listening
100s: Timeout - deployment fails
```

## Solution
Made database initialization **completely non-blocking**:

### Changes to `app/database.py`

1. **Immediate client creation**: Create Supabase clients instantly without testing connection
2. **Background connection test**: Moved connection testing to `_test_database_connection()` background task
3. **Non-blocking async**: Used `asyncio.to_thread()` to make sync Supabase calls non-blocking
4. **Always return True**: `init_db()` always returns True so server starts immediately

### New Flow
```
0s:   Container starts
0.1s: Create Supabase clients (instant)
0.2s: Server listening on PORT ✅
0.3s: Railway healthcheck succeeds ✅
0-15s: Background task tests database connection
15s:  Database verified ✅
```

## Configuration Updates

### `railway.toml`
- **healthcheckTimeout**: Increased to 300 seconds (5 minutes) to handle any startup delays
- **restartPolicyMaxRetries**: Increased to 10 for better resilience

### Benefits
1. ✅ Server responds to healthchecks immediately
2. ✅ Database issues don't prevent server startup
3. ✅ API runs in "degraded mode" until database connects
4. ✅ Better fault tolerance and observability

## Testing
To test locally:
```bash
cd server
python3 scripts/railway_start.py &
sleep 1
curl http://localhost:8000/health
# Should return: {"status":"healthy","version":"1.0.0","service":"SniffTest API"}
```

## Deployment
These changes ensure Railway healthchecks pass consistently:
1. Server starts listening within 1-2 seconds
2. `/health` endpoint responds immediately
3. Database connection happens in background
4. App is usable even if database is temporarily unavailable

## Related Files
- `server/app/database.py` - Database initialization
- `server/main.py` - FastAPI app with lifespan management
- `server/railway.toml` - Railway deployment configuration
- `server/scripts/railway_start.py` - Railway startup script

