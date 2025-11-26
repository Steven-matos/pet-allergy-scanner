"""
Centralized error handling decorator

This is the SINGLE SOURCE OF TRUTH for:
1. Standardized error handling in API endpoints
2. Consistent error logging and response format
3. Proper HTTPException handling

All endpoint error handling should use this decorator for consistency.
"""

import logging
from functools import wraps
from typing import Callable, Any
from fastapi import HTTPException, status

logger = logging.getLogger(__name__)


def handle_errors(operation_name: str):
    """
    Decorator for standardized error handling in API endpoints
    
    This decorator ensures consistent error handling across all endpoints:
    - HTTPExceptions are re-raised as-is
    - Other exceptions are logged and converted to 500 errors
    
    Args:
        operation_name: Name of the operation for logging purposes
        
    Usage:
        @handle_errors("create_pet")
        async def create_pet(...):
            # endpoint code
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        async def async_wrapper(*args: Any, **kwargs: Any) -> Any:
            try:
                return await func(*args, **kwargs)
            except HTTPException:
                # Re-raise HTTPExceptions as-is
                raise
            except Exception as e:
                logger.error(f"Error in {operation_name}: {e}", exc_info=True)
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail=f"Internal server error: {str(e)}"
                )
        
        @wraps(func)
        def sync_wrapper(*args: Any, **kwargs: Any) -> Any:
            try:
                return func(*args, **kwargs)
            except HTTPException:
                # Re-raise HTTPExceptions as-is
                raise
            except Exception as e:
                logger.error(f"Error in {operation_name}: {e}", exc_info=True)
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail=f"Internal server error: {str(e)}"
                )
        
        # Return appropriate wrapper based on whether function is async
        if hasattr(func, '__code__'):
            import inspect
            if inspect.iscoroutinefunction(func):
                return async_wrapper
        return sync_wrapper
    
    return decorator


def handle_errors_with_custom_message(operation_name: str, custom_message: str):
    """
    Decorator for standardized error handling with custom error message
    
    Similar to handle_errors but allows custom error messages.
    
    Args:
        operation_name: Name of the operation for logging purposes
        custom_message: Custom error message to return to client
        
    Usage:
        @handle_errors_with_custom_message("fetch_pets", "Failed to fetch pets")
        async def fetch_pets(...):
            # endpoint code
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        async def async_wrapper(*args: Any, **kwargs: Any) -> Any:
            try:
                return await func(*args, **kwargs)
            except HTTPException:
                # Re-raise HTTPExceptions as-is
                raise
            except Exception as e:
                logger.error(f"Error in {operation_name}: {e}", exc_info=True)
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail=f"{custom_message}: {str(e)}"
                )
        
        @wraps(func)
        def sync_wrapper(*args: Any, **kwargs: Any) -> Any:
            try:
                return func(*args, **kwargs)
            except HTTPException:
                # Re-raise HTTPExceptions as-is
                raise
            except Exception as e:
                logger.error(f"Error in {operation_name}: {e}", exc_info=True)
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail=f"{custom_message}: {str(e)}"
                )
        
        # Return appropriate wrapper based on whether function is async
        if hasattr(func, '__code__'):
            import inspect
            if inspect.iscoroutinefunction(func):
                return async_wrapper
        return sync_wrapper
    
    return decorator

