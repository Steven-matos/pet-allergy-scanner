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
    
    This dependency creates a Supabase client and sets the user's authentication
    session, allowing RLS policies to work correctly.
    
    Args:
        credentials: HTTP authorization credentials from the request
        
    Returns:
        Authenticated Supabase client instance
    """
    from supabase import create_client
    
    supabase = create_client(
        settings.supabase_url,
        settings.supabase_key
    )
    supabase.auth.set_session(credentials.credentials, "")
    
    return supabase
