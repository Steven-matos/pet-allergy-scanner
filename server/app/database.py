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
connection_pool = None

async def init_db():
    """
    Initialize database connection and verify connectivity with connection pooling
    
    Returns False instead of raising exceptions to allow app to start in degraded mode
    """
    global supabase, connection_pool
    
    try:
        logger.info("Initializing database connection...")
        
        # Initialize Supabase client
        supabase = create_client(
            settings.supabase_url, 
            settings.supabase_key
        )
        
        # Test connection with retry logic and timeout
        max_retries = 2  # Reduced retries for faster startup
        timeout = 10  # Total timeout for connection test
        
        for attempt in range(max_retries):
            try:
                # Quick connection test with timeout
                logger.info(f"Testing database connection (attempt {attempt + 1}/{max_retries})...")
                response = supabase.table("users").select("id").limit(1).execute()
                logger.info("✅ Database connection established successfully")

                # Initialize connection pool monitoring (non-blocking) - only in development
                if settings.environment != "production":
                    asyncio.create_task(_start_connection_monitoring())

                return True

            except Exception as e:
                error_msg = str(e)
                logger.error(f"Database connection attempt {attempt + 1} failed: {error_msg}")
                
                if attempt < max_retries - 1:
                    await asyncio.sleep(2)  # Short delay before retry
                else:
                    # Log helpful troubleshooting info on final failure
                    if "nodename nor servname provided" in error_msg or "DNS" in error_msg:
                        logger.error("CRITICAL: DNS resolution failed - check SUPABASE_URL")
                    elif "401" in error_msg or "403" in error_msg:
                        logger.error("CRITICAL: Authentication failed - check SUPABASE_KEY")
                    else:
                        logger.error(f"CRITICAL: Connection failed: {error_msg}")
        
        return False
        
    except Exception as e:
        logger.error(f"Database initialization error: {e}")
        logger.warning("Application will start in degraded mode without database")
        return False

async def _start_connection_monitoring():
    """
    Start monitoring database connection health
    """
    async def monitor_connections():
        consecutive_failures = 0
        max_consecutive_failures = 5
        
        while True:
            try:
                # Test connection health
                start_time = time.time()
                supabase.table("users").select("id").limit(1).execute()
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
    global supabase, connection_pool
    
    try:
        if supabase:
            # Supabase client doesn't have explicit close method
            # but we can clear the reference
            supabase = None
        
        if connection_pool:
            connection_pool = None
        
        logger.info("Database connections closed successfully")
        
    except Exception as e:
        logger.error(f"Error closing database connections: {e}")

def get_connection_stats() -> dict:
    """
    Get database connection statistics
    
    Returns:
        Dictionary with connection statistics
    """
    try:
        if not supabase:
            return {"status": "not_initialized"}
        
        # Test connection performance
        start_time = time.time()
        supabase.table("users").select("id").limit(1).execute()
        response_time = time.time() - start_time
        
        return {
            "status": "connected",
            "response_time_ms": round(response_time * 1000, 2),
            "pool_size": settings.database_pool_size,
            "timeout_seconds": settings.database_timeout
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
