"""
Centralized pagination response builder

This is the SINGLE SOURCE OF TRUTH for:
1. Building paginated responses with has_more calculation
2. Consistent pagination response format
3. Standardized pagination metadata

All pagination responses should use this service for consistency.
"""

from typing import List, TypeVar, Generic, Type
from pydantic import BaseModel

T = TypeVar('T')


class PaginationResponse(BaseModel, Generic[T]):
    """
    Standard pagination response model
    
    Generic pagination response that can be used with any data type.
    """
    items: List[T]
    total_count: int
    has_more: bool
    offset: int
    limit: int


class PaginationService:
    """
    Centralized service for building pagination responses
    
    This ensures:
    - Consistent pagination response format
    - Standardized has_more calculation
    - Easier maintenance of pagination logic
    """
    
    @staticmethod
    def build_pagination_response(
        items: List[T],
        total_count: int,
        offset: int,
        limit: int
    ) -> PaginationResponse[T]:
        """
        Build paginated response with has_more calculation
        
        Args:
            items: List of items for current page
            total_count: Total number of items available
            offset: Current offset
            limit: Current limit
            
        Returns:
            PaginationResponse with items, total_count, has_more, offset, and limit
        """
        return PaginationResponse(
            items=items,
            total_count=total_count,
            has_more=(offset + limit) < total_count,
            offset=offset,
            limit=limit
        )
    
    @staticmethod
    def calculate_has_more(
        total_count: int,
        offset: int,
        limit: int
    ) -> bool:
        """
        Calculate if there are more results available
        
        Args:
            total_count: Total number of items available
            offset: Current offset
            limit: Current limit
            
        Returns:
            True if there are more results, False otherwise
        """
        return (offset + limit) < total_count
    
    @staticmethod
    def calculate_total_pages(total_count: int, limit: int) -> int:
        """
        Calculate total number of pages
        
        Args:
            total_count: Total number of items available
            limit: Items per page
            
        Returns:
            Total number of pages
        """
        if limit <= 0:
            return 0
        return (total_count + limit - 1) // limit  # Ceiling division
    
    @staticmethod
    def calculate_current_page(offset: int, limit: int) -> int:
        """
        Calculate current page number (1-indexed)
        
        Args:
            offset: Current offset
            limit: Items per page
            
        Returns:
            Current page number (1-indexed)
        """
        if limit <= 0:
            return 1
        return (offset // limit) + 1

