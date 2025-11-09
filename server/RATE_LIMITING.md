# Rate Limiting Implementation Status

## Current Implementation

The API currently uses **in-memory rate limiting** implemented in `app/middleware/security.py` using Python `deque` objects.

### How It Works
- Rate limits are stored in memory per process
- Default limits: 60 requests/minute (general), 5 requests/minute (auth endpoints)
- Limits are tracked by client IP address
- Old entries are cleaned up every 60 seconds

### Limitations ⚠️

**CRITICAL**: This implementation has significant limitations in production:

1. **Multi-instance problem**: Each API instance maintains its own rate limit counters
   - If you scale to 3 instances, effective rate limit is 3x the configured limit
   - A malicious actor can bypass limits by distributing requests across instances

2. **Process restart resets limits**: Counters are lost on restart/crash
   - No persistence means limits don't survive deployments
   - Attackers can exploit this by triggering restarts

3. **Memory growth**: For high-traffic scenarios, the deque structures can grow unbounded
   - Current implementation limits to recent entries, but can still accumulate

4. **No distributed coordination**: Instances don't communicate about rate limits

## Production Recommendations

### Option 1: Redis-based Rate Limiting (Recommended)

**Pros:**
- Shared state across all API instances
- Persistent across restarts
- Fast lookups (sub-millisecond)
- Mature ecosystem with libraries like `slowapi` or `fastapi-limiter`

**Implementation:**
```python
# Install: pip install redis fastapi-limiter

from fastapi_limiter import FastAPILimiter
from fastapi_limiter.depends import RateLimiter
import redis.asyncio as redis

@app.on_event("startup")
async def startup():
    redis_connection = await redis.from_url(
        "redis://localhost", 
        encoding="utf-8", 
        decode_responses=True
    )
    await FastAPILimiter.init(redis_connection)

# Use in routes:
@router.get("/", dependencies=[Depends(RateLimiter(times=60, seconds=60))])
async def endpoint():
    pass
```

**Cost:** ~$5-10/month for managed Redis (Railway, Upstash, Redis Labs)

### Option 2: API Gateway Rate Limiting

Use your hosting platform's built-in rate limiting:
- **Railway**: No built-in rate limiting, needs external solution
- **Cloudflare**: Free tier includes rate limiting
- **AWS API Gateway**: Built-in rate limiting with token bucket algorithm
- **Kong/Tyk**: Open-source API gateways with rate limiting

### Option 3: Keep Current (Development Only)

If you're in early development with low traffic:
- Document the limitation clearly
- Monitor for abuse
- Plan migration to Redis before scaling
- Set aggressive limits (lower than needed) as safety buffer

## Migration Path

1. **Immediate**: Add Redis to your Railway project
2. **Update**: Install `fastapi-limiter` and configure
3. **Test**: Verify rate limiting works across multiple requests
4. **Deploy**: Roll out gradually with monitoring
5. **Remove**: Delete old `RateLimitMiddleware` code

## Configuration

Current rate limits are set in `app/core/config.py`:
```python
rate_limit_per_minute: int = 60
auth_rate_limit_per_minute: int = 5
```

## Monitoring

**Important**: Set up monitoring for:
- Rate limit hits (how often users hit the limit)
- Unusual traffic patterns (potential DDoS)
- Per-endpoint usage to tune limits appropriately

## Status

- [x] In-memory rate limiting implemented
- [ ] Redis integration planned
- [ ] Monitoring/alerting not configured
- [ ] Load testing not performed

## Last Updated
2025-11-09

## See Also
- `server/app/middleware/security.py` - Current implementation
- `server/app/core/config.py` - Rate limit configuration

