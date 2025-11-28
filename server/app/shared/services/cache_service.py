"""
Server-side caching service for performance optimization

Provides in-memory and Redis-based caching for frequently accessed data to reduce
database load and improve response times, especially for mobile users.

Supports both in-memory caching (default) and Redis caching (when configured)
for distributed systems and better scalability.
"""

from typing import Optional, Any, Dict, Callable
import time
import logging
import json
from functools import wraps
from app.core.config import settings

logger = logging.getLogger(__name__)

# Try to import Redis for distributed caching
try:
    import redis.asyncio as aioredis
    REDIS_AVAILABLE = True
except ImportError:
    REDIS_AVAILABLE = False
    logger.warning("Redis not available - falling back to in-memory caching only")


class CacheEntry:
    """Cache entry with expiration"""
    
    def __init__(self, data: Any, ttl: float):
        """
        Initialize cache entry
        
        Args:
            data: Cached data
            ttl: Time to live in seconds
        """
        self.data = data
        self.created_at = time.time()
        self.ttl = ttl
    
    def is_expired(self) -> bool:
        """Check if cache entry has expired"""
        return time.time() - self.created_at > self.ttl
    
    def get_age(self) -> float:
        """Get age of cache entry in seconds"""
        return time.time() - self.created_at


class CacheService:
    """
    Hybrid cache service supporting both in-memory and Redis caching
    
    Provides caching for:
    - Static reference data (allergens, food database)
    - User/pet profiles (short TTL)
    - Search results (very short TTL)
    - API response caching
    
    Automatically uses Redis if available and configured, otherwise falls back to in-memory cache.
    """
    
    _instance: Optional['CacheService'] = None
    _cache: Dict[str, CacheEntry] = {}
    _redis_client: Optional[Any] = None
    _use_redis: bool = False
    
    # Cache TTL defaults (in seconds)
    TTL_STATIC = 3600 * 24  # 24 hours for static data
    TTL_USER_PROFILE = 1800  # 30 minutes for user profiles
    TTL_PET_PROFILE = 1800  # 30 minutes for pet profiles
    TTL_SEARCH_RESULTS = 300  # 5 minutes for search results
    TTL_FOOD_ITEMS = 3600  # 1 hour for food items
    TTL_API_RESPONSE = 600  # 10 minutes for API responses
    
    def __new__(cls):
        """Singleton pattern"""
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialize_redis()
        return cls._instance
    
    def _initialize_redis(self) -> None:
        """Initialize Redis client if available and configured"""
        if not REDIS_AVAILABLE:
            self._use_redis = False
            return
        
        try:
            redis_url = settings.redis_url
            if redis_url:
                self._redis_client = aioredis.from_url(
                    redis_url,
                    decode_responses=True,
                    socket_connect_timeout=2,
                    socket_timeout=2
                )
                self._use_redis = True
                logger.info("Redis cache initialized successfully")
            else:
                # Try host/port configuration
                redis_host = settings.redis_host
                redis_port = settings.redis_port
                if redis_host:
                    self._redis_client = aioredis.Redis(
                        host=redis_host,
                        port=redis_port,
                        decode_responses=True,
                        socket_connect_timeout=2,
                        socket_timeout=2
                    )
                    self._use_redis = True
                    logger.info(f"Redis cache initialized with host/port: {redis_host}:{redis_port}")
                else:
                    self._use_redis = False
                    logger.info("Redis not configured - using in-memory cache only")
        except Exception as e:
            logger.warning(f"Failed to initialize Redis cache: {e}. Falling back to in-memory cache.")
            self._use_redis = False
            self._redis_client = None
    
    async def get(self, key: str) -> Optional[Any]:
        """
        Get cached value (async for Redis support)
        
        Args:
            key: Cache key
            
        Returns:
            Cached value or None if not found/expired
        """
        if self._use_redis and self._redis_client:
            try:
                value = await self._redis_client.get(key)
                if value:
                    return json.loads(value)
                return None
            except Exception as e:
                logger.warning(f"Redis get error for key {key}: {e}. Falling back to in-memory cache.")
                # Fall through to in-memory cache
        
        # In-memory cache fallback
        entry = self._cache.get(key)
        
        if entry is None:
            return None
        
        if entry.is_expired():
            del self._cache[key]
            return None
        
        return entry.data
    
    async def set(self, key: str, value: Any, ttl: Optional[float] = None) -> None:
        """
        Set cached value (async for Redis support)
        
        Args:
            key: Cache key
            value: Value to cache
            ttl: Time to live in seconds (uses default if None)
        """
        if ttl is None:
            ttl = self.TTL_USER_PROFILE  # Default TTL
        
        if self._use_redis and self._redis_client:
            try:
                serialized_value = json.dumps(value)
                await self._redis_client.setex(key, int(ttl), serialized_value)
                return
            except Exception as e:
                logger.warning(f"Redis set error for key {key}: {e}. Falling back to in-memory cache.")
                # Fall through to in-memory cache
        
        # In-memory cache fallback
        self._cache[key] = CacheEntry(value, ttl)
    
    async def delete(self, key: str) -> None:
        """
        Delete cached value (async for Redis support)
        
        Args:
            key: Cache key
        """
        if self._use_redis and self._redis_client:
            try:
                await self._redis_client.delete(key)
            except Exception as e:
                logger.warning(f"Redis delete error for key {key}: {e}")
        
        # Also delete from in-memory cache
        self._cache.pop(key, None)
    
    def clear(self) -> None:
        """Clear all cache entries"""
        self._cache.clear()
    
    def invalidate_pattern(self, pattern: str) -> None:
        """
        Invalidate cache entries matching a pattern
        
        Args:
            pattern: String pattern to match (simple substring match)
        """
        keys_to_delete = [key for key in self._cache.keys() if pattern in key]
        for key in keys_to_delete:
            del self._cache[key]
    
    def get_stats(self) -> Dict[str, Any]:
        """
        Get cache statistics
        
        Returns:
            Dictionary with cache statistics
        """
        total_entries = len(self._cache)
        expired_entries = sum(1 for entry in self._cache.values() if entry.is_expired())
        active_entries = total_entries - expired_entries
        
        return {
            "total_entries": total_entries,
            "active_entries": active_entries,
            "expired_entries": expired_entries,
            "memory_usage_estimate": total_entries * 1024  # Rough estimate in bytes
        }
    
    def cleanup_expired(self) -> int:
        """
        Remove expired cache entries
        
        Returns:
            Number of entries removed
        """
        expired_keys = [key for key, entry in self._cache.items() if entry.is_expired()]
        for key in expired_keys:
            del self._cache[key]
        return len(expired_keys)


# Global cache service instance
cache_service = CacheService()


def cached(ttl: Optional[float] = None, key_prefix: str = ""):
    """
    Decorator to cache function results (async-aware)
    
    Args:
        ttl: Time to live in seconds (uses default if None)
        key_prefix: Prefix for cache key
    
    Usage:
        @cached(ttl=3600, key_prefix="user")
        async def get_user(user_id: str):
            ...
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Generate cache key from function name and arguments
            cache_key = f"{key_prefix}:{func.__name__}:{str(args)}:{str(kwargs)}"
            
            # Try to get from cache (async)
            cached_result = await cache_service.get(cache_key)
            if cached_result is not None:
                return cached_result
            
            # Execute function and cache result (async)
            result = await func(*args, **kwargs)
            await cache_service.set(cache_key, result, ttl)
            
            return result
        
        return wrapper
    return decorator

