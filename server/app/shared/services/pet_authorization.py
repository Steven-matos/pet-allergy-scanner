"""
Pet authorization service

Centralized pet ownership verification to eliminate code duplication.
Used across 15+ locations in the codebase.

Follows DRY principle: Single source of truth for pet authorization
"""

from fastapi import HTTPException, status
from typing import Any, Dict

from app.database import get_supabase_client
from app.models.user import User


async def verify_pet_ownership(
    pet_id: str, 
    user_id: str,
    db = None
) -> Dict[str, Any]:
    """
    Verify that a user owns a specific pet
    
    Args:
        pet_id: Pet ID to verify
        user_id: User ID claiming ownership
        db: Optional database session (uses Supabase by default)
        
    Returns:
        Pet data if ownership verified
        
    Raises:
        HTTPException: 404 if pet not found or user not authorized
        
    Example:
        >>> pet = await verify_pet_ownership(pet_id, current_user.id)
        >>> # Proceed with pet operation
    """
    supabase = db or get_supabase_client()
    
    response = supabase.table("pets")\
        .select("*")\
        .eq("id", pet_id)\
        .eq("user_id", user_id)\
        .execute()
    
    if not response.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pet not found or access denied"
        )
    
    return response.data[0]
