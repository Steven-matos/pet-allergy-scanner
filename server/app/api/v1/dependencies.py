"""
Shared dependencies for API v1

Centralized dependency injection for FastAPI endpoints

This module will be fully populated during Day 3-4 (Security & Validation Split)
For now, it provides basic dependency re-exports from existing modules.
"""

from fastapi import Depends

# Use new refactored modules
from app.core.security.jwt_handler import get_current_user

from app.database import get_supabase_client

# Import shared services
from app.shared.services.pet_authorization import verify_pet_ownership
from app.shared.services.user_metadata_mapper import UserMetadataMapper

# Re-export common dependencies
__all__ = [
    'get_current_user',
    'get_supabase_client',
    'verify_pet_ownership',
    'UserMetadataMapper'
]
