"""
Response utility functions

This is the SINGLE SOURCE OF TRUTH for:
1. Handling empty responses consistently
2. Standardized empty response handling patterns

All empty response handling should use this utility for consistency.
"""

from typing import List, Dict, Any, Optional, TYPE_CHECKING

if TYPE_CHECKING:
    # QueryResponse may not be available in all supabase versions
    try:
        from supabase.lib.client_types import QueryResponse
    except ImportError:
        QueryResponse = Any  # Fallback if not available
else:
    QueryResponse = Any  # Use Any at runtime to avoid import issues


def handle_empty_response(response_data: Optional[List[Dict[str, Any]]]) -> List[Dict[str, Any]]:
    """
    Handle empty response consistently across the application
    
    This ensures standardized empty response handling throughout the codebase.
    If the response data is None or empty, return an empty list.
    
    Args:
        response_data: Response data from database query
        
    Returns:
        Empty list if response_data is None or empty, otherwise returns response_data
    """
    if not response_data:
        return []
    return response_data


def handle_empty_query_response(response: QueryResponse) -> List[Dict[str, Any]]:
    """
    Handle empty Supabase query response consistently
    
    Args:
        response: Supabase QueryResponse object
        
    Returns:
        Empty list if response.data is None or empty, otherwise returns response.data
    """
    return handle_empty_response(response.data if hasattr(response, 'data') else None)

