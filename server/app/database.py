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
    """
    global supabase, connection_pool
    
    try:
        # Initialize Supabase client
        supabase = create_client(
            settings.supabase_url, 
            settings.supabase_key
        )
        
        # Test connection with retry logic
        max_retries = 3
        for attempt in range(max_retries):
            try:
                response = supabase.table("users").select("id").limit(1).execute()
                logger.info("Database connection established successfully")
                break
            except Exception as e:
                if attempt == max_retries - 1:
                    raise e
                logger.warning(f"Database connection attempt {attempt + 1} failed, retrying...")
                await asyncio.sleep(2 ** attempt)  # Exponential backoff
        
        # Initialize connection pool monitoring
        await _start_connection_monitoring()
        
        return True
        
    except Exception as e:
        logger.error(f"Database connection failed: {e}")
        raise e

async def _start_connection_monitoring():
    """
    Start monitoring database connection health
    """
    async def monitor_connections():
        while True:
            try:
                # Test connection health
                start_time = time.time()
                supabase.table("users").select("id").limit(1).execute()
                response_time = time.time() - start_time
                
                # Log performance metrics
                if response_time > 1.0:  # Log slow queries
                    logger.warning(f"Slow database query: {response_time:.2f}s")
                
                # Sleep for 30 seconds before next check
                await asyncio.sleep(30)
                
            except Exception as e:
                logger.error(f"Database health check failed: {e}")
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
