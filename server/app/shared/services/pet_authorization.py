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
        db: Optional authenticated Supabase client (uses unauthenticated client by default)
        
    Returns:
        Pet data if ownership verified
        
    Raises:
        HTTPException: 404 if pet not found or user not authorized
        
    Note:
        When db is provided (authenticated client), RLS policies will automatically
        filter by auth.uid(). The explicit user_id filter is kept for additional
        security and to work with unauthenticated clients.
        
    Example:
        >>> pet = await verify_pet_ownership(pet_id, current_user.id, authenticated_supabase)
        >>> # Proceed with pet operation
    """
    import logging
    logger = logging.getLogger(__name__)
    
    supabase = db or get_supabase_client()
    
    # Query pet by ID
    # If db is an authenticated client, RLS will automatically filter by auth.uid()
    # Try querying with RLS first (without explicit user_id filter) if authenticated client
    # This ensures RLS policies are properly enforced
    if db is not None:
        # Authenticated client - rely on RLS to filter by auth.uid()
        # RLS policy: (select auth.uid()) = user_id
        logger.debug(f"Verifying pet ownership with authenticated client: pet_id={pet_id}, user_id={user_id}")
        try:
            response = supabase.table("pets")\
                .select("*")\
                .eq("id", pet_id)\
                .execute()
            
            logger.debug(f"RLS query returned {len(response.data) if response.data else 0} results")
            
            # Verify the pet belongs to the expected user (double-check)
            if response.data:
                found_user_id = response.data[0].get("user_id")
                if found_user_id != user_id:
                    logger.warning(
                        f"Pet {pet_id} found via RLS but belongs to different user. "
                        f"Expected: {user_id}, Found: {found_user_id}. "
                        f"This suggests RLS auth.uid() != expected user_id"
                    )
                    raise HTTPException(
                        status_code=status.HTTP_404_NOT_FOUND,
                        detail="Pet not found or access denied"
                    )
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error querying pet with authenticated client: {e}")
            # Fall back to explicit user_id filter
            logger.debug("Falling back to explicit user_id filter")
            response = supabase.table("pets")\
                .select("*")\
                .eq("id", pet_id)\
                .eq("user_id", user_id)\
                .execute()
    else:
        # Unauthenticated client - must filter explicitly
        logger.debug(f"Verifying pet ownership with unauthenticated client: pet_id={pet_id}, user_id={user_id}")
        response = supabase.table("pets")\
            .select("*")\
            .eq("id", pet_id)\
            .eq("user_id", user_id)\
            .execute()
    
    if not response.data:
        # Log for debugging - check if pet exists at all
        # Note: This check might also be blocked by RLS if using authenticated client
        try:
            # Use service role client to check if pet exists (bypasses RLS)
            from app.database import get_supabase_service_role_client
            service_client = get_supabase_service_role_client()
            pet_check = service_client.table("pets")\
                .select("id, user_id")\
                .eq("id", pet_id)\
                .execute()
            
            if pet_check.data:
                actual_owner = pet_check.data[0].get("user_id")
                logger.warning(
                    f"Pet {pet_id} exists but user {user_id} does not own it. "
                    f"Pet owner: {actual_owner}"
                )
            else:
                logger.warning(f"Pet {pet_id} not found in database")
        except Exception as check_error:
            # If service role check fails, just log the original error
            logger.debug(f"Could not verify pet existence: {check_error}")
        
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pet not found or access denied"
        )
    
    return response.data[0]
