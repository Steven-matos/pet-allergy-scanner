"""
Database configuration and initialization with connection pooling
"""

from supabase import create_client, Client
from app.core.config import settings
import logging
import asyncio
from typing import Optional
import time

logger = logging.getLogger(__name__)

# Global Supabase client with connection pooling
supabase: Optional[Client] = None
supabase_service_role: Optional[Client] = None
connection_pool = None

async def init_db():
    """
    Initialize database connection with non-blocking startup
    
    Server starts immediately, database connection happens in background.
    This ensures Railway healthchecks pass even if database is slow to connect.
    
    Returns True immediately to allow server to start
    """
    global supabase, supabase_service_role
    
    try:
        
        # Initialize Supabase clients immediately (no blocking operations)
        supabase = create_client(
            settings.supabase_url, 
            settings.supabase_key
        )
        
        supabase_service_role = create_client(
            settings.supabase_url,
            settings.supabase_service_role_key
        )
        
        
        # Test connection in background (non-blocking)
        asyncio.create_task(_test_database_connection())
        
        # Always return True so server starts immediately
        return True
        
    except Exception as e:
        logger.error(f"Database client creation error: {e}")
        logger.warning("Application will start without database clients")
        return True  # Still return True to let server start


async def _test_database_connection():
    """
    Test database connection in background without blocking server startup
    """
    try:
        max_retries = 3
        retry_delay = 3  # seconds
        
        for attempt in range(max_retries):
            try:
                
                # Use asyncio.to_thread to make sync call non-blocking
                await asyncio.wait_for(
                    asyncio.to_thread(
                        lambda: supabase.table("users").select("id").limit(1).execute()
                    ),
                    timeout=5.0  # 5 second timeout per attempt
                )
                
                
                # Start monitoring in non-production only
                if settings.environment != "production":
                    asyncio.create_task(_start_connection_monitoring())
                
                return
                
            except asyncio.TimeoutError:
                logger.warning(f"Database connection attempt {attempt + 1} timed out")
                if attempt < max_retries - 1:
                    await asyncio.sleep(retry_delay)
                    
            except Exception as e:
                error_msg = str(e)
                logger.error(f"Database connection attempt {attempt + 1} failed: {error_msg}")
                
                if attempt < max_retries - 1:
                    await asyncio.sleep(retry_delay)
                else:
                    # Log troubleshooting info on final failure
                    if "nodename nor servname provided" in error_msg or "DNS" in error_msg:
                        logger.error("CRITICAL: DNS resolution failed - check SUPABASE_URL")
                    elif "401" in error_msg or "403" in error_msg:
                        logger.error("CRITICAL: Authentication failed - check SUPABASE_KEY")
                    else:
                        logger.error(f"CRITICAL: Connection failed: {error_msg}")
        
        logger.warning("⚠️  Database connection test failed, but server is running")
        logger.warning("    API endpoints requiring database will fail until connection is restored")
        
    except Exception as e:
        logger.error(f"Database connection test error: {e}")
        logger.warning("Server running in degraded mode")

async def _start_connection_monitoring():
    """
    Start monitoring database connection health (non-production only)
    """
    async def monitor_connections():
        global supabase
        consecutive_failures = 0
        max_consecutive_failures = 5
        
        # Wait a bit before starting to ensure connection is established
        await asyncio.sleep(10)
        
        while True:
            try:
                if supabase is None:
                    logger.warning("Database client not initialized, skipping health check")
                    await asyncio.sleep(30)
                    continue
                
                # Test connection health
                start_time = time.time()
                await asyncio.to_thread(
                    lambda: supabase.table("users").select("id").limit(1).execute()
                )
                response_time = time.time() - start_time
                
                # Reset failure counter on success
                consecutive_failures = 0
                
                # Log performance metrics - only in development
                if settings.environment != "production" and response_time > 1.0:
                    logger.warning(f"Slow database query: {response_time:.2f}s")

                # Sleep for 30 seconds before next check
                await asyncio.sleep(30)
                
            except Exception as e:
                consecutive_failures += 1
                error_msg = str(e)
                
                if "nodename nor servname provided" in error_msg:
                    logger.error(f"DNS resolution failed during health check: {error_msg}")
                    # Stop monitoring if DNS issues persist
                    if consecutive_failures >= max_consecutive_failures:
                        logger.error("Stopping database monitoring due to persistent DNS issues")
                        break
                else:
                    # Only log errors in development to reduce production noise
                    if settings.environment != "production":
                        logger.error(f"Database health check failed: {error_msg}")

                # Check more frequently on failure, but stop if too many consecutive failures
                if consecutive_failures >= max_consecutive_failures:
                    if settings.environment != "production":
                        logger.error("Stopping database monitoring due to persistent connection issues")
                    break

                await asyncio.sleep(10)  # Check more frequently on failure
    
    # Start monitoring task
    asyncio.create_task(monitor_connections())

def get_supabase_client() -> Client:
    """
    Get Supabase client instance with connection pooling
    """
    global supabase
    
    if supabase is None:
        raise RuntimeError("Database not initialized. Call init_db() first.")
    
    return supabase

async def close_db():
    """
    Close database connections and cleanup
    """
    global supabase, supabase_service_role, connection_pool
    
    try:
        if supabase:
            # Supabase client doesn't have explicit close method
            # but we can clear the reference
            supabase = None
        
        if supabase_service_role:
            supabase_service_role = None
        
        if connection_pool:
            connection_pool = None
        
        
    except Exception as e:
        logger.error(f"Error closing database connections: {e}")

async def get_connection_stats() -> dict:
    """
    Get connection pool statistics and health metrics
    
    Returns:
        Dictionary with connection statistics including:
        - status: Connection status
        - response_time_ms: Query response time in milliseconds
        - pool_size: Configured pool size
        - timeout_seconds: Query timeout setting
        - connection_reuse: Whether connection reuse is enabled (True - using global client)
        - client_instances: Number of client instances (should be 2: anon + service_role)
    """
    try:
        if not supabase:
            return {"status": "not_initialized"}
        
        # Test connection performance (non-blocking)
        start_time = time.time()
        await asyncio.wait_for(
            asyncio.to_thread(
                lambda: supabase.table("users").select("id").limit(1).execute()
            ),
            timeout=5.0
        )
        response_time = time.time() - start_time
        
        # Count active client instances
        client_count = sum([
            1 if supabase else 0,
            1 if supabase_service_role else 0
        ])
        
        return {
            "status": "connected",
            "response_time_ms": round(response_time * 1000, 2),
            "pool_size": settings.database_pool_size,
            "timeout_seconds": settings.database_timeout,
            "connection_reuse": True,  # Using global client instances
            "client_instances": client_count,
            "note": "Supabase Python client uses httpx connection pooling internally"
        }
        
    except asyncio.TimeoutError:
        return {
            "status": "timeout",
            "error": "Connection test timed out after 5s"
        }
    except Exception as e:
        return {
            "status": "error",
            "error": str(e)
        }

def get_db():
    """
    Dependency to get database client for FastAPI routes
    """
    return get_supabase_client()

def get_supabase_service_role_client() -> Client:
    """
    Get Supabase client instance with service role key for backend operations
    This client bypasses RLS and should be used for server-side operations only
    
    Returns:
        Supabase client with service role permissions
        
    Raises:
        RuntimeError: If database not initialized
    """
    global supabase_service_role
    
    if supabase_service_role is None:
        raise RuntimeError("Database not initialized. Call init_db() first.")
    
    return supabase_service_role
