"""
Shared dependencies for API v1

Centralized dependency injection for FastAPI endpoints

This module will be fully populated during Day 3-4 (Security & Validation Split)
For now, it provides basic dependency re-exports from existing modules.
"""

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials
from supabase import Client

# Use new refactored modules
from app.core.security.jwt_handler import get_current_user, security
from app.core.config import settings
from app.database import get_supabase_client

# Import shared services
from app.shared.services.pet_authorization import verify_pet_ownership
from app.shared.services.user_metadata_mapper import UserMetadataMapper

# Re-export common dependencies
__all__ = [
    'get_current_user',
    'get_supabase_client',
    'get_authenticated_supabase_client',
    'verify_pet_ownership',
    'UserMetadataMapper'
]


def get_authenticated_supabase_client(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> Client:
    """
    Get an authenticated Supabase client with user session
    
    This dependency creates a new client instance with the JWT token set in the session,
    allowing RLS policies to work correctly. Each request gets its own client instance
    to avoid session conflicts.
    
    Args:
        credentials: HTTP authorization credentials from the request
        
    Returns:
        Authenticated Supabase client instance with session set
    """
    from supabase import create_client
    
    # Create a new client instance for this request to avoid session conflicts
    # This ensures RLS policies work correctly with the JWT token
    supabase = create_client(
        settings.supabase_url,
        settings.supabase_key
    )
    
    # Set user session for RLS policies
    # Pass the access token as both access_token and refresh_token
    # The Supabase client will decode the JWT and set the user context for RLS
    try:
        # Try to set session with the JWT token
        # For RLS to work, we need to set the session so PostgREST can extract auth.uid()
        supabase.auth.set_session(credentials.credentials, credentials.credentials)
    except Exception as session_error:
        # If set_session fails, log but continue - the explicit user_id filter will work
        import logging
        logger = logging.getLogger(__name__)
        logger.warning(f"Failed to set Supabase session: {session_error}. RLS may not work, but explicit filters will.")
    
    return supabase
