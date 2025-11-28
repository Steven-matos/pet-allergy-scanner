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
    
    According to Supabase Python 2.9.1 documentation:
    - Creates a new client instance per request to avoid session conflicts
    - Sets session using set_session(access_token, refresh_token)
    - PostgREST should automatically use session's access token for RLS policies
    
    Args:
        credentials: HTTP authorization credentials from the request
        
    Returns:
        Authenticated Supabase client instance with session properly configured
        
    Note:
        Since we only have access_token in the request context (not refresh_token),
        we use access_token for both. This works for RLS but refresh won't work.
        This is a limitation of our current architecture.
    """
    from app.shared.services.supabase_auth_service import SupabaseAuthService
    
    # Use centralized service to create authenticated client
    # This follows Supabase Python 2.9.1 documentation exactly
    # Note: We only have access_token, not refresh_token, in request context
    # This is a limitation but RLS will still work
    return SupabaseAuthService.create_authenticated_client(
        access_token=credentials.credentials,
        refresh_token=None  # Not available in request context
    )
