"""
Base repository for common CRUD operations

Follows Repository Pattern for data access abstraction
Implements DRY: Common database operations in one place
"""

from typing import Generic, TypeVar, Type, Optional, List, Any, Dict
from abc import ABC, abstractmethod

from app.shared.services.query_builder_service import QueryBuilderService
from app.shared.services.pagination_service import PaginationService, PaginationResponse


T = TypeVar('T')


class BaseRepository(ABC, Generic[T]):
    """
    Base repository with common CRUD operations
    
    Provides standard database operations that can be inherited
    by domain-specific repositories.
    
    Type Parameters:
        T: The model type this repository works with
    """
    
    def __init__(self, supabase, table_name: str):
        """
        Initialize repository
        
        Args:
            supabase: Supabase client instance
            table_name: Name of the database table
        """
        self.supabase = supabase
        self.table_name = table_name
    
    async def get_by_id(self, id: str) -> Optional[Dict[str, Any]]:
        """
        Get entity by ID
        
        Args:
            id: Entity ID
            
        Returns:
            Entity data or None if not found
        """
        response = self.supabase.table(self.table_name)\
            .select("*")\
            .eq("id", id)\
            .execute()
        
        return response.data[0] if response.data else None
    
    async def get_all(
        self, 
        filters: Optional[Dict[str, Any]] = None,
        limit: int = 100,
        offset: int = 0
    ) -> List[Dict[str, Any]]:
        """
        Get all entities with optional filtering
        
        Args:
            filters: Optional dictionary of field:value filters
            limit: Maximum number of results to return
            offset: Number of results to skip
            
        Returns:
            List of entity data dictionaries
        """
        query = self.supabase.table(self.table_name).select("*")
        
        if filters:
            for key, value in filters.items():
                query = query.eq(key, value)
        
        response = query.limit(limit).offset(offset).execute()
        return response.data or []
    
    async def create(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Create new entity
        
        Args:
            data: Entity data to insert
            
        Returns:
            Created entity data
            
        Raises:
            Exception: If creation fails
        """
        response = self.supabase.table(self.table_name)\
            .insert(data)\
            .execute()
        
        if not response.data:
            raise Exception(f"Failed to create {self.table_name} record")
        
        return response.data[0]
    
    async def update(self, id: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Update existing entity
        
        Args:
            id: Entity ID
            data: Fields to update
            
        Returns:
            Updated entity data
            
        Raises:
            Exception: If update fails or entity not found
        """
        response = self.supabase.table(self.table_name)\
            .update(data)\
            .eq("id", id)\
            .execute()
        
        if not response.data:
            raise Exception(f"Failed to update {self.table_name} record with id {id}")
        
        return response.data[0]
    
    async def delete(self, id: str) -> bool:
        """
        Delete entity by ID
        
        Args:
            id: Entity ID
            
        Returns:
            True if deleted, False if not found
        """
        response = self.supabase.table(self.table_name)\
            .delete()\
            .eq("id", id)\
            .execute()
        
        return bool(response.data)
    
    async def count(self, filters: Optional[Dict[str, Any]] = None) -> int:
        """
        Count entities with optional filtering
        
        Args:
            filters: Optional dictionary of field:value filters
            
        Returns:
            Count of matching entities
        """
        query = self.supabase.table(self.table_name).select("id", count="exact")
        
        if filters:
            for key, value in filters.items():
                query = query.eq(key, value)
        
        response = query.execute()
        return response.count or 0
    
    async def exists(self, id: str) -> bool:
        """
        Check if entity exists
        
        Args:
            id: Entity ID
            
        Returns:
            True if exists, False otherwise
        """
        entity = await self.get_by_id(id)
        return entity is not None
    
    def build_query(self) -> QueryBuilderService:
        """
        Create a query builder for this repository's table
        
        Returns:
            QueryBuilderService instance configured for this table
        """
        return QueryBuilderService(self.supabase, self.table_name)
    
    async def search(
        self,
        search_fields: List[str],
        search_term: Optional[str] = None,
        filters: Optional[Dict[str, Any]] = None,
        limit: int = 100,
        offset: int = 0,
        order_by: Optional[str] = None,
        desc: bool = True,
        include_count: bool = False
    ) -> Dict[str, Any]:
        """
        Search entities with filters, pagination, and ordering
        
        Args:
            search_fields: List of field names to search in
            search_term: Search term to look for
            filters: Optional dictionary of field:value filters
            limit: Maximum number of results
            offset: Number of results to skip
            order_by: Field name to order by
            desc: Whether to order descending
            include_count: Whether to include total count
            
        Returns:
            Dictionary with 'data' and 'count' keys
        """
        query_builder = self.build_query()
        
        if filters:
            query_builder.with_filters(filters)
        
        if search_term and search_fields:
            query_builder.with_search(search_fields, search_term)
        
        if order_by:
            query_builder.with_ordering(order_by, desc)
        
        query_builder.with_pagination(limit, offset, include_count)
        
        return query_builder.execute()
    
    async def get_paginated(
        self,
        filters: Optional[Dict[str, Any]] = None,
        limit: int = 100,
        offset: int = 0,
        order_by: Optional[str] = None,
        desc: bool = True
    ) -> PaginationResponse[Dict[str, Any]]:
        """
        Get paginated results with has_more calculation
        
        Args:
            filters: Optional dictionary of field:value filters
            limit: Maximum number of results
            offset: Number of results to skip
            order_by: Field name to order by
            desc: Whether to order descending
            
        Returns:
            PaginationResponse with items, total_count, has_more, offset, and limit
        """
        query_builder = self.build_query()
        
        if filters:
            query_builder.with_filters(filters)
        
        if order_by:
            query_builder.with_ordering(order_by, desc)
        
        result = query_builder.with_pagination(limit, offset, include_count=True).execute()
        
        return PaginationService.build_pagination_response(
            items=result["data"],
            total_count=result["count"],
            offset=offset,
            limit=limit
        )
    
    async def get_all_with_ordering(
        self,
        filters: Optional[Dict[str, Any]] = None,
        limit: int = 100,
        offset: int = 0,
        order_by: str = "created_at",
        desc: bool = True
    ) -> List[Dict[str, Any]]:
        """
        Get all entities with optional filtering and ordering
        
        Args:
            filters: Optional dictionary of field:value filters
            limit: Maximum number of results to return
            offset: Number of results to skip
            order_by: Field name to order by
            desc: Whether to order descending
            
        Returns:
            List of entity data dictionaries
        """
        query_builder = self.build_query()
        
        if filters:
            query_builder.with_filters(filters)
        
        query_builder.with_ordering(order_by, desc)
        
        result = query_builder.with_pagination(limit, offset).execute()
        return result["data"]
