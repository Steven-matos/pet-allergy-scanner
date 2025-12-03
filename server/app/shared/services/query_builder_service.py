"""
Centralized query builder service

This is the SINGLE SOURCE OF TRUTH for:
1. Building Supabase queries with filters, pagination, and ordering
2. Consistent query construction patterns
3. Standardized search and filter logic

All query building should use this service for consistency.
"""

from typing import Dict, Any, List, Optional, TYPE_CHECKING
from supabase import Client
import logging
import asyncio
from app.core.config import settings

if TYPE_CHECKING:
    # QueryResponse may not be available in all supabase versions
    try:
        from supabase.lib.client_types import QueryResponse
    except ImportError:
        QueryResponse = Any  # Fallback if not available
else:
    QueryResponse = Any  # Use Any at runtime to avoid import issues

logger = logging.getLogger(__name__)


class QueryBuilderService:
    """
    Centralized service for building Supabase queries
    
    This ensures:
    - Consistent query patterns across the application
    - Standardized filtering, pagination, and search
    - Easier maintenance of query logic
    """
    
    # Maximum limit to prevent excessive data fetching
    MAX_LIMIT = 500
    
    def __init__(self, supabase: Client, table_name: str, default_columns: Optional[List[str]] = None, include_count: bool = False):
        """
        Initialize query builder service
        
        Args:
            supabase: Supabase client instance
            table_name: Name of the database table
            default_columns: Optional list of default columns to select (None means all)
                            Use None only when you explicitly need all columns
            include_count: Whether to include total count in the query response
        """
        self.supabase = supabase
        self.table_name = table_name
        self._include_count = include_count
        
        if default_columns:
            select_str = ",".join(default_columns)
            if include_count:
                self.query = supabase.table(table_name).select(select_str, count="exact")
            else:
                self.query = supabase.table(table_name).select(select_str)
        else:
            # Default to all columns but warn in development
            if settings.environment == "development":
                logger.warning(
                    f"QueryBuilderService initialized without explicit columns for {table_name}. "
                    "Consider specifying columns for better performance."
                )
            if include_count:
                self.query = supabase.table(table_name).select("*", count="exact")
            else:
                self.query = supabase.table(table_name).select("*")
    
    def with_filters(self, filters: Dict[str, Any]) -> 'QueryBuilderService':
        """
        Add equality filters to the query
        
        Args:
            filters: Dictionary of field:value filters (None values are ignored)
            
        Returns:
            Self for method chaining
        """
        for key, value in filters.items():
            if value is not None:
                self.query = self.query.eq(key, value)
        return self
    
    def with_search(
        self, 
        search_fields: List[str], 
        search_term: Optional[str]
    ) -> 'QueryBuilderService':
        """
        Add search across multiple fields using ILIKE
        
        Note: Supabase Python client has limitations with complex OR conditions.
        This method searches the first field primarily. For multi-field search,
        consider using PostgreSQL full-text search or searching fields separately.
        
        Args:
            search_fields: List of field names to search in (first field is used)
            search_term: Search term to look for (None values are ignored)
            
        Returns:
            Self for method chaining
        """
        if search_term and search_fields:
            # Use the first field for primary search
            # Supabase Python client doesn't easily support OR across multiple fields
            # For better multi-field search, consider using PostgreSQL's text search
            primary_field = search_fields[0]
            self.query = self.query.ilike(primary_field, f"%{search_term}%")
            
            # Log if multiple fields were requested but only first is used
            if len(search_fields) > 1:
                logger.debug(
                    f"Multi-field search requested for {search_fields}, "
                    f"but only searching in {primary_field} due to Supabase client limitations. "
                    f"Consider using PostgreSQL full-text search for better multi-field support."
                )
        return self
    
    def with_ilike(self, field: str, pattern: Optional[str]) -> 'QueryBuilderService':
        """
        Add ILIKE filter for case-insensitive pattern matching
        
        Uses PostgreSQL's ILIKE operator which performs case-insensitive matching.
        This ensures that searches match regardless of case variations in the database.
        For example: "Weruva", "WERUVA", "weruva" all match the same records.
        
        Args:
            field: Field name to search in
            pattern: Pattern to match (None values are ignored)
                    The pattern is wrapped with % wildcards for partial matching
                    Example: "weruva" becomes "%weruva%" to match "Weruva Classic"
            
        Returns:
            Self for method chaining
        """
        if pattern:
            # PostgreSQL ILIKE is case-insensitive by default
            # Pattern is wrapped with % for partial matching
            self.query = self.query.ilike(field, f"%{pattern}%")
        return self
    
    def with_pagination(
        self, 
        limit: int, 
        offset: int, 
        include_count: bool = False
    ) -> 'QueryBuilderService':
        """
        Add pagination to the query
        
        Args:
            limit: Maximum number of results (will be capped at MAX_LIMIT)
            offset: Number of results to skip
            include_count: Whether to include total count in response
            
        Returns:
            Self for method chaining
        """
        # Enforce maximum limit to prevent excessive data fetching
        if limit > self.MAX_LIMIT:
            logger.warning(
                f"Limit {limit} exceeds MAX_LIMIT ({self.MAX_LIMIT}) for {self.table_name}. "
                f"Capping at {self.MAX_LIMIT}."
            )
            limit = self.MAX_LIMIT
        
        # Apply range for pagination
        self.query = self.query.range(offset, offset + limit - 1)
        
        # Note: count="exact" should be specified in the initial select() call
        # We cannot add it later as the query builder doesn't support modifying select after creation
        # If count is needed, it should be specified when creating the query builder
        if include_count:
            # Try to get the current select string from the query
            # If we can't determine it, we'll need to rebuild the query
            # For now, we'll log a warning and continue without count
            # The proper way is to specify count in the initial select() call
            logger.debug(
                f"include_count=True requested but count must be specified in initial select(). "
                f"Count will not be included in this query result."
            )
        
        return self
    
    def with_ordering(
        self, 
        field: str, 
        desc: bool = True
    ) -> 'QueryBuilderService':
        """
        Add ordering to the query
        
        Args:
            field: Field name to order by
            desc: Whether to order descending (True) or ascending (False)
            
        Returns:
            Self for method chaining
        """
        self.query = self.query.order(field, desc=desc)
        return self
    
    def with_limit(self, limit: int) -> 'QueryBuilderService':
        """
        Add limit to the query
        
        Args:
            limit: Maximum number of results (will be capped at MAX_LIMIT)
            
        Returns:
            Self for method chaining
        """
        # Enforce maximum limit
        if limit > self.MAX_LIMIT:
            logger.warning(
                f"Limit {limit} exceeds MAX_LIMIT ({self.MAX_LIMIT}) for {self.table_name}. "
                f"Capping at {self.MAX_LIMIT}."
            )
            limit = self.MAX_LIMIT
        self.query = self.query.limit(limit)
        return self
    
    def select(self, columns: Optional[List[str]] = None, count: Optional[str] = None) -> 'QueryBuilderService':
        """
        Specify columns to select (resets query)
        
        Args:
            columns: List of column names (None means select all)
            count: Optional count mode ("exact" to include total count)
            
        Returns:
            Self for method chaining
        """
        if columns:
            select_str = ",".join(columns)
            if count:
                self.query = self.supabase.table(self.table_name).select(select_str, count=count)
            else:
                self.query = self.supabase.table(self.table_name).select(select_str)
        else:
            if count:
                self.query = self.supabase.table(self.table_name).select("*", count=count)
            else:
                self.query = self.supabase.table(self.table_name).select("*")
        return self
    
    def _execute_sync(self) -> Dict[str, Any]:
        """
        Synchronous query execution (internal use only)
        
        Returns:
            Dictionary with 'data' and 'count' keys
        """
        try:
            response: QueryResponse = self.query.execute()
            return {
                "data": response.data or [],
                "count": response.count if hasattr(response, 'count') and response.count else len(response.data or [])
            }
        except Exception as e:
            logger.error(f"Error executing query on {self.table_name}: {e}")
            raise
    
    async def execute(self, timeout: Optional[float] = None) -> Dict[str, Any]:
        """
        Execute query asynchronously with optional timeout
        
        Tracks query execution time and logs slow queries (>500ms) for performance monitoring.
        
        Args:
            timeout: Optional timeout in seconds (uses database_timeout from config if None)
        
        Returns:
            Dictionary with 'data' and 'count' keys
        """
        import time
        query_timeout = timeout or settings.database_timeout
        start_time = time.time()
        
        try:
            # Execute in thread pool to avoid blocking event loop
            response = await asyncio.wait_for(
                asyncio.to_thread(self._execute_sync),
                timeout=query_timeout
            )
            
            # Track query execution time
            execution_time = time.time() - start_time
            
            # Log slow queries (>500ms) for performance monitoring
            SLOW_QUERY_THRESHOLD = 0.5  # 500ms
            if execution_time > SLOW_QUERY_THRESHOLD:
                logger.warning(
                    f"Slow query detected: {self.table_name} took {execution_time:.3f}s "
                    f"(threshold: {SLOW_QUERY_THRESHOLD}s)"
                )
            
            return response
        except asyncio.TimeoutError:
            execution_time = time.time() - start_time
            logger.error(
                f"Query timeout after {query_timeout}s on {self.table_name} "
                f"(execution time: {execution_time:.3f}s)"
            )
            raise TimeoutError(f"Database query timed out after {query_timeout} seconds")
        except Exception as e:
            execution_time = time.time() - start_time
            logger.error(
                f"Error executing async query on {self.table_name} "
                f"(execution time: {execution_time:.3f}s): {e}"
            )
            raise
    
    def execute_sync(self) -> Dict[str, Any]:
        """
        Synchronous query execution (for use in sync contexts only)
        
        WARNING: This blocks the event loop. Use execute() in async contexts.
        
        Returns:
            Dictionary with 'data' and 'count' keys
        """
        return self._execute_sync()
    
    def _execute_raw_sync(self) -> QueryResponse:
        """
        Synchronous raw query execution (internal use only)
        
        Returns:
            Raw QueryResponse object
        """
        try:
            return self.query.execute()
        except Exception as e:
            logger.error(f"Error executing raw query on {self.table_name}: {e}")
            raise
    
    async def execute_raw(self, timeout: Optional[float] = None) -> QueryResponse:
        """
        Execute query asynchronously and return raw Supabase response
        
        Args:
            timeout: Optional timeout in seconds (uses database_timeout from config if None)
        
        Returns:
            Raw QueryResponse object
        """
        query_timeout = timeout or settings.database_timeout
        
        try:
            response = await asyncio.wait_for(
                asyncio.to_thread(self._execute_raw_sync),
                timeout=query_timeout
            )
            return response
        except asyncio.TimeoutError:
            logger.error(
                f"Raw query timeout after {query_timeout}s on {self.table_name}"
            )
            raise TimeoutError(f"Database query timed out after {query_timeout} seconds")
        except Exception as e:
            logger.error(f"Error executing async raw query on {self.table_name}: {e}")
            raise
    
    def with_user_and_pet_filter(
        self, 
        user_id: Optional[str] = None, 
        pet_id: Optional[str] = None
    ) -> 'QueryBuilderService':
        """
        Add common user_id and pet_id filters (abstracted pattern)
        
        This is a common pattern across many services where queries filter by
        both user_id and pet_id for authorization and data scoping.
        
        Args:
            user_id: Optional user ID to filter by
            pet_id: Optional pet ID to filter by
            
        Returns:
            Self for method chaining
        """
        if user_id:
            self.query = self.query.eq("user_id", user_id)
        if pet_id:
            self.query = self.query.eq("pet_id", pet_id)
        return self
    
    def with_date_range(
        self,
        date_field: str,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None
    ) -> 'QueryBuilderService':
        """
        Add date range filters (abstracted pattern)
        
        Common pattern for filtering records within a date range.
        Used for trends, history, and time-based analytics.
        
        Args:
            date_field: Name of the date field to filter on
            start_date: Optional start date (ISO format string)
            end_date: Optional end date (ISO format string)
            
        Returns:
            Self for method chaining
        """
        if start_date:
            self.query = self.query.gte(date_field, start_date)
        if end_date:
            self.query = self.query.lte(date_field, end_date)
        return self
    
    def with_common_pagination_and_ordering(
        self,
        limit: int = 20,
        offset: int = 0,
        order_by: str = "created_at",
        desc: bool = True,
        include_count: bool = False
    ) -> 'QueryBuilderService':
        """
        Add common pagination and ordering pattern (abstracted)
        
        This combines pagination and ordering which is a very common pattern
        across list endpoints. Reduces code duplication.
        
        IMPORTANT: If include_count=True, the QueryBuilderService must be initialized
        with include_count=True in the constructor. Count cannot be added after query
        building has started.
        
        Args:
            limit: Maximum number of results
            offset: Number of results to skip
            order_by: Field name to order by (default: created_at)
            desc: Whether to order descending
            include_count: Whether to include total count (must be set at initialization)
            
        Returns:
            Self for method chaining
        """
        self.with_ordering(order_by, desc)
        # Note: include_count must be set at initialization, so pass False here
        # The count will be included if the query builder was initialized with include_count=True
        self.with_pagination(limit, offset, include_count=False)
        return self
    
    def reset(self, default_columns: Optional[List[str]] = None) -> 'QueryBuilderService':
        """
        Reset query builder to initial state
        
        Args:
            default_columns: Optional list of columns to select (None means all)
        
        Returns:
            Self for method chaining
        """
        if default_columns:
            select_str = ",".join(default_columns)
            self.query = self.supabase.table(self.table_name).select(select_str)
        else:
            self.query = self.supabase.table(self.table_name).select("*")
        return self

