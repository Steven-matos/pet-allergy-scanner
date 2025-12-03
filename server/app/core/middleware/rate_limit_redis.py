"""
Redis-backed rate limiting middleware for production

Provides distributed rate limiting using Redis when available,
with automatic fallback to in-memory rate limiting if Redis is unavailable.
"""

from fastapi import Request, Response
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import ASGIApp
import time
import logging
from typing import Dict, Optional
from collections import defaultdict, deque
from app.core.config import settings

logger = logging.getLogger(__name__)

# Try to import Redis
try:
    import redis.asyncio as redis
    REDIS_AVAILABLE = True
except ImportError:
    REDIS_AVAILABLE = False
    logger.warning("Redis not available. Rate limiting will use in-memory storage.")


class RedisRateLimitMiddleware(BaseHTTPMiddleware):
    """
    Redis-backed rate limiting middleware with in-memory fallback
    
    Uses Redis for distributed rate limiting in production when available,
    falls back to in-memory rate limiting if Redis is unavailable.
    """
    
    def __init__(self, app: ASGIApp):
        super().__init__(app)
        self.redis_client: Optional[redis.Redis] = None
        self.use_redis = False
        
        # Fallback in-memory rate limits
        self.rate_limits: Dict[str, deque] = defaultdict(lambda: deque())
        self.auth_limits: Dict[str, deque] = defaultdict(lambda: deque())
        self.cleanup_interval = 60
        self.last_cleanup = time.time()
        
        # Initialize Redis connection if available
        self._init_redis()
    
    def _init_redis(self):
        """Initialize Redis connection if available"""
        if not REDIS_AVAILABLE:
            logger.info("Using in-memory rate limiting (Redis not available)")
            return
        
        try:
            # Try to get Redis URL from environment
            redis_url = getattr(settings, 'redis_url', None)
            
            # Skip Redis if URL is None or explicitly set to 'none'
            if not redis_url or redis_url.lower() == 'none':
                logger.info("Redis not configured. Using in-memory rate limiting.")
                return
            
            # Try to construct from host/port if URL not provided
            if not redis_url.startswith('redis://'):
                redis_host = getattr(settings, 'redis_host', None)
                redis_port = getattr(settings, 'redis_port', 6379)
                
                # Skip if host is None or 'none'
                if not redis_host or redis_host.lower() == 'none':
                    logger.info("Redis not configured. Using in-memory rate limiting.")
                    return
                
                redis_url = f"redis://{redis_host}:{redis_port}"
            
            self.redis_client = redis.from_url(
                redis_url,
                decode_responses=True,
                socket_connect_timeout=2,
                socket_timeout=2
            )
            self.use_redis = True
            logger.info("Redis rate limiting enabled")
        except Exception as e:
            logger.warning(f"Failed to connect to Redis: {e}. Using in-memory rate limiting.")
            self.use_redis = False
    
    def _get_client_ip(self, request: Request) -> str:
        """Get client IP address"""
        forwarded_for = request.headers.get("X-Forwarded-For")
        if forwarded_for:
            return forwarded_for.split(",")[0].strip()
        
        real_ip = request.headers.get("X-Real-IP")
        if real_ip:
            return real_ip
        
        return request.client.host if request.client else "unknown"
    
    def _is_auth_endpoint(self, path: str) -> bool:
        """Check if the endpoint is an authentication endpoint"""
        auth_paths = [
            "/api/v1/auth/login",
            "/api/v1/auth/register",
            "/api/v1/auth/forgot-password",
            "/api/v1/auth/refresh"
        ]
        return any(path.startswith(auth_path) for auth_path in auth_paths)
    
    def _is_logout_endpoint(self, path: str) -> bool:
        """Check if the endpoint is the logout endpoint"""
        return path.startswith("/api/v1/auth/logout")
    
    def _is_login_endpoint(self, path: str) -> bool:
        """Check if the endpoint is the login endpoint"""
        return path.startswith("/api/v1/auth/login")
    
    def _should_skip_rate_limit(self, path: str) -> bool:
        """
        Check if rate limiting should be skipped for this endpoint.
        Login and logout are essential operations and should not be rate limited.
        
        Args:
            path: Request path
            
        Returns:
            True if rate limiting should be skipped
        """
        return self._is_login_endpoint(path) or self._is_logout_endpoint(path)
    
    async def _clear_auth_rate_limit(self, client_ip: str):
        """Clear auth rate limit entries for a specific IP (used after successful logout)"""
        if self.use_redis and self.redis_client:
            try:
                await self.redis_client.delete(f"rate_limit:auth:{client_ip}")
            except Exception as e:
                logger.warning(f"Failed to clear Redis auth rate limit: {e}")
        
        # Also clear in-memory fallback
        if client_ip in self.auth_limits:
            del self.auth_limits[client_ip]
    
    async def _check_rate_limit_redis(self, key: str, limit: int, window: int = 60) -> tuple[bool, int, int]:
        """
        Check rate limit using Redis
        
        Args:
            key: Rate limit key
            limit: Maximum requests allowed
            window: Time window in seconds
        
        Returns:
            Tuple of (is_allowed, remaining, reset_time)
        """
        if not self.redis_client:
            return True, limit, int(time.time() + window)
        
        try:
            current = await self.redis_client.get(key)
            current_count = int(current) if current else 0
            
            if current_count >= limit:
                ttl = await self.redis_client.ttl(key)
                return False, 0, int(time.time() + (ttl if ttl > 0 else window))
            
            # Increment counter
            pipe = self.redis_client.pipeline()
            pipe.incr(key)
            pipe.expire(key, window)
            await pipe.execute()
            
            remaining = max(0, limit - current_count - 1)
            return True, remaining, int(time.time() + window)
        except Exception as e:
            logger.warning(f"Redis rate limit check failed: {e}. Falling back to in-memory.")
            self.use_redis = False
            return True, limit, int(time.time() + window)
    
    def _check_rate_limit_memory(self, rate_queue: deque, limit: int) -> tuple[bool, int, int]:
        """
        Check rate limit using in-memory storage
        
        Args:
            rate_queue: Deque of request timestamps
            limit: Maximum requests allowed
        
        Returns:
            Tuple of (is_allowed, remaining, reset_time)
        """
        current_time = time.time()
        cutoff_time = current_time - 60  # 1 minute window
        
        # Remove old entries
        while rate_queue and rate_queue[0] < cutoff_time:
            rate_queue.popleft()
        
        # Check if limit exceeded
        if len(rate_queue) >= limit:
            return False, 0, int(current_time + 60)
        
        # Add current request
        rate_queue.append(current_time)
        remaining = max(0, limit - len(rate_queue))
        return True, remaining, int(current_time + 60)
    
    async def dispatch(self, request: Request, call_next):
        """
        Apply rate limiting
        
        Login and logout endpoints are excluded from rate limiting as they are
        essential operations that users should be able to perform without restrictions.
        """
        client_ip = self._get_client_ip(request)
        current_time = time.time()
        
        # Skip rate limiting for login and logout endpoints (essential operations)
        if self._should_skip_rate_limit(request.url.path):
            # Clear auth rate limit on successful logout
            if self._is_logout_endpoint(request.url.path):
                response = await call_next(request)
                if response.status_code == 200:
                    await self._clear_auth_rate_limit(client_ip)
                return response
            
            # For login, just process the request without rate limiting
            response = await call_next(request)
            return response
        
        # Determine rate limit based on endpoint
        if self._is_auth_endpoint(request.url.path):
            limit = settings.auth_rate_limit_per_minute
            is_auth = True
        else:
            limit = settings.rate_limit_per_minute
            is_auth = False
        
        # Check rate limit
        if self.use_redis:
            rate_key = f"rate_limit:{'auth' if is_auth else 'api'}:{client_ip}"
            is_allowed, remaining, reset_time = await self._check_rate_limit_redis(rate_key, limit)
        else:
            # Use in-memory rate limiting
            rate_queue = self.auth_limits[client_ip] if is_auth else self.rate_limits[client_ip]
            is_allowed, remaining, reset_time = self._check_rate_limit_memory(rate_queue, limit)
            
            # Cleanup old entries periodically
            if current_time - self.last_cleanup > self.cleanup_interval:
                self._cleanup_old_entries()
                self.last_cleanup = current_time
        
        if not is_allowed:
            if settings.environment != "production":
                logger.warning(f"Rate limit exceeded for IP: {client_ip}, Path: {request.url.path}")
            return JSONResponse(
                status_code=429,
                content={
                    "detail": "Rate limit exceeded. Please try again later.",
                    "retry_after": reset_time - int(current_time)
                },
                headers={
                    "X-RateLimit-Limit": str(limit),
                    "X-RateLimit-Remaining": "0",
                    "X-RateLimit-Reset": str(reset_time)
                }
            )
        
        # Process request
        response = await call_next(request)
        
        # Add rate limit headers
        response.headers["X-RateLimit-Limit"] = str(limit)
        response.headers["X-RateLimit-Remaining"] = str(remaining)
        response.headers["X-RateLimit-Reset"] = str(reset_time)
        
        return response
    
    def _cleanup_old_entries(self):
        """Clean up old rate limit entries (in-memory only)"""
        current_time = time.time()
        cutoff_time = current_time - 60
        
        for ip in list(self.rate_limits.keys()):
            while self.rate_limits[ip] and self.rate_limits[ip][0] < cutoff_time:
                self.rate_limits[ip].popleft()
            if not self.rate_limits[ip]:
                del self.rate_limits[ip]
        
        for ip in list(self.auth_limits.keys()):
            while self.auth_limits[ip] and self.auth_limits[ip][0] < cutoff_time:
                self.auth_limits[ip].popleft()
            if not self.auth_limits[ip]:
                del self.auth_limits[ip]

