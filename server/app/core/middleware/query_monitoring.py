"""
Query performance monitoring middleware

Tracks database query performance and logs slow queries
for performance optimization.
"""

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import ASGIApp
import time
import logging
from typing import Dict, List
from collections import defaultdict

logger = logging.getLogger(__name__)


class QueryMonitoringMiddleware(BaseHTTPMiddleware):
    """
    Middleware to monitor query performance
    
    Tracks:
    - Query execution times
    - Slow queries (>500ms)
    - Query patterns
    """
    
    # Threshold for slow query logging (in seconds)
    SLOW_QUERY_THRESHOLD = 0.5  # 500ms
    
    def __init__(self, app: ASGIApp):
        super().__init__(app)
        self.query_times: List[float] = []
        self.slow_queries: List[Dict[str, any]] = []
        self.query_patterns: Dict[str, int] = defaultdict(int)
    
    async def dispatch(self, request: Request, call_next):
        """Monitor request processing time"""
        start_time = time.time()
        
        # Process request
        response = await call_next(request)
        
        # Calculate processing time
        processing_time = time.time() - start_time
        
        # Log slow requests
        if processing_time > self.SLOW_QUERY_THRESHOLD:
            logger.warning(
                f"Slow request: {request.method} {request.url.path} "
                f"took {processing_time:.3f}s"
            )
        
        # Add performance header
        response.headers["X-Response-Time"] = f"{processing_time:.3f}s"
        
        return response
    
    def log_slow_query(self, table_name: str, query_time: float, query_type: str = "select"):
        """
        Log slow database query
        
        Args:
            table_name: Name of the table queried
            query_time: Query execution time in seconds
            query_type: Type of query (select, insert, update, delete)
        """
        if query_time > self.SLOW_QUERY_THRESHOLD:
            slow_query_info = {
                "table": table_name,
                "query_type": query_type,
                "execution_time": query_time,
                "timestamp": time.time()
            }
            self.slow_queries.append(slow_query_info)
            
            logger.warning(
                f"Slow query detected: {query_type} on {table_name} "
                f"took {query_time:.3f}s"
            )
    
    def get_stats(self) -> Dict[str, any]:
        """
        Get query performance statistics
        
        Returns:
            Dictionary with performance stats
        """
        if not self.query_times:
            return {
                "total_queries": 0,
                "avg_query_time": 0,
                "max_query_time": 0,
                "slow_queries_count": len(self.slow_queries)
            }
        
        return {
            "total_queries": len(self.query_times),
            "avg_query_time": sum(self.query_times) / len(self.query_times),
            "max_query_time": max(self.query_times),
            "min_query_time": min(self.query_times),
            "slow_queries_count": len(self.slow_queries),
            "query_patterns": dict(self.query_patterns)
        }

