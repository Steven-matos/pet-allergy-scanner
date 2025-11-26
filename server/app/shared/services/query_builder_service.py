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
    
    def __init__(self, supabase: Client, table_name: str):
        """
        Initialize query builder service
        
        Args:
            supabase: Supabase client instance
            table_name: Name of the database table
        """
        self.supabase = supabase
        self.table_name = table_name
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
        
        Args:
            search_fields: List of field names to search in
            search_term: Search term to look for (None values are ignored)
            
        Returns:
            Self for method chaining
        """
        if search_term:
            conditions = ",".join([
                f"{field}.ilike.%{search_term}%" for field in search_fields
            ])
            self.query = self.query.or_(conditions)
        return self
    
    def with_ilike(self, field: str, pattern: Optional[str]) -> 'QueryBuilderService':
        """
        Add ILIKE filter for case-insensitive pattern matching
        
        Args:
            field: Field name to search in
            pattern: Pattern to match (None values are ignored)
            
        Returns:
            Self for method chaining
        """
        if pattern:
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
            limit: Maximum number of results
            offset: Number of results to skip
            include_count: Whether to include total count in response
            
        Returns:
            Self for method chaining
        """
        if include_count:
            self.query = self.query.select("*", count="exact")
        self.query = self.query.range(offset, offset + limit - 1)
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
            limit: Maximum number of results
            
        Returns:
            Self for method chaining
        """
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
    
    def execute(self) -> Dict[str, Any]:
        """
        Execute query and return results
        
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
    
    def execute_raw(self) -> QueryResponse:
        """
        Execute query and return raw Supabase response
        
        Returns:
            Raw QueryResponse object
        """
        try:
            return self.query.execute()
        except Exception as e:
            logger.error(f"Error executing raw query on {self.table_name}: {e}")
            raise
    
    def reset(self) -> 'QueryBuilderService':
        """
        Reset query builder to initial state
        
        Returns:
            Self for method chaining
        """
        self.query = self.supabase.table(self.table_name).select("*")
        return self

