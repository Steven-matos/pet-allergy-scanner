"""
Async utilities for Supabase queries

Provides async wrappers for synchronous Supabase operations
to prevent blocking the event loop.
"""

import asyncio
import time
import logging
from typing import Any, Callable, TypeVar
from app.core.config import settings

T = TypeVar('T')
logger = logging.getLogger(__name__)

# Threshold for slow query logging (in seconds)
SLOW_QUERY_THRESHOLD = 0.5  # 500ms


async def execute_async(query_func: Callable[[], T], timeout: float = None, table_name: str = None) -> T:
    """
    Execute a synchronous Supabase query asynchronously
    
    Tracks query execution time and logs slow queries (>500ms) for performance monitoring.
    
    Args:
        query_func: Function that executes the Supabase query
        timeout: Optional timeout in seconds (uses database_timeout from config if None)
        table_name: Optional table name for logging context
    
    Returns:
        Query result
    
    Raises:
        TimeoutError: If query exceeds timeout
    """
    query_timeout = timeout or settings.database_timeout
    start_time = time.time()
    
    try:
        result = await asyncio.wait_for(
            asyncio.to_thread(query_func),
            timeout=query_timeout
        )
        
        # Track query execution time
        execution_time = time.time() - start_time
        
        # Log slow queries (>500ms) for performance monitoring
        if execution_time > SLOW_QUERY_THRESHOLD:
            table_info = f" on {table_name}" if table_name else ""
            logger.warning(
                f"Slow query detected{table_info}: took {execution_time:.3f}s "
                f"(threshold: {SLOW_QUERY_THRESHOLD}s)"
            )
        
        return result
    except asyncio.TimeoutError:
        execution_time = time.time() - start_time
        table_info = f" on {table_name}" if table_name else ""
        logger.error(
            f"Query timeout after {query_timeout}s{table_info} "
            f"(execution time: {execution_time:.3f}s)"
        )
        raise TimeoutError(f"Database query timed out after {query_timeout} seconds")

