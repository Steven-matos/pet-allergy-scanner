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
from app.shared.utils.async_supabase import execute_async


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
        # Check if client is actually authenticated
        try:
            session = supabase.auth.get_session()
            if session:
                auth_user_id = session.user.id if hasattr(session, 'user') and session.user else None
                if auth_user_id and auth_user_id != user_id:
                    logger.warning(
                        f"[PET_AUTH] Session user_id mismatch! Session auth.uid()={auth_user_id}, "
                        f"but expected user_id={user_id}. This may cause RLS to block access."
                    )
        except Exception as session_error:
            logger.warning(f"[PET_AUTH] Could not verify session: {session_error}")
        
        # Try RLS query first (without explicit user_id filter)
        # If RLS is working, this should return the pet if user owns it
        try:
            response = await execute_async(
                lambda: supabase.table("pets")
                    .select("*")
                    .eq("id", pet_id)
                    .execute()
            )
            
            if response.data:
                found_pet = response.data[0]
                found_user_id = found_pet.get("user_id")
                
                # Verify the pet belongs to the expected user (double-check)
                if found_user_id != user_id:
                    logger.error(
                        f"[PET_AUTH] Pet {pet_id} found via RLS but belongs to different user. "
                        f"Expected: {user_id}, Found: {found_user_id}."
                    )
                    raise HTTPException(
                        status_code=status.HTTP_404_NOT_FOUND,
                        detail="Pet not found or access denied"
                    )
                # Success - RLS worked and pet belongs to user
                return found_pet
            else:
                # RLS query returned no results - RLS might not be working
                # Fall back to explicit user_id filter
                logger.warning(
                    f"[PET_AUTH] RLS query returned no results for pet_id={pet_id}. "
                    f"Falling back to explicit user_id filter. This may indicate RLS session not properly set."
                )
        except HTTPException:
            raise
        except Exception as e:
            logger.warning(
                f"[PET_AUTH] RLS query failed: {type(e).__name__}: {e}. "
                f"Falling back to explicit user_id filter."
            )
        
        # Fallback: Use explicit user_id filter (works even if RLS isn't properly configured)
        # This ensures the query works regardless of RLS session state
        try:
            response = await execute_async(
                lambda: supabase.table("pets")
                    .select("*")
                    .eq("id", pet_id)
                    .eq("user_id", user_id)
                    .execute()
            )
        except Exception as fallback_error:
            logger.error(f"[PET_AUTH] Fallback query also failed: {type(fallback_error).__name__}: {fallback_error}", exc_info=True)
            raise
    else:
        # Unauthenticated client - must filter explicitly
        response = await execute_async(
            lambda: supabase.table("pets")
                .select("*")
                .eq("id", pet_id)
                .eq("user_id", user_id)
                .execute()
        )
    
    if not response.data:
        # Log for debugging - check if pet exists at all
        # Note: This check might also be blocked by RLS if using authenticated client
        logger.warning(f"[PET_AUTH] Pet query returned no results. Checking if pet exists in database...")
        try:
            # Use service role client to check if pet exists (bypasses RLS)
            from app.database import get_supabase_service_role_client
            service_client = get_supabase_service_role_client()
            pet_check = await execute_async(
                lambda: service_client.table("pets")
                    .select("id, user_id, name, created_at")
                    .eq("id", pet_id)
                    .execute()
            )
            
            if pet_check.data:
                pet_info = pet_check.data[0]
                actual_owner = pet_info.get("user_id")
                pet_name = pet_info.get("name", "Unknown")
                logger.error(
                    f"[PET_AUTH] Pet {pet_id} ({pet_name}) EXISTS in database but query returned no results. "
                    f"Pet owner in DB: {actual_owner}, Requesting user_id: {user_id}. "
                    f"This indicates either: 1) RLS policy blocking access, 2) Session not properly authenticated, "
                    f"3) user_id mismatch. Pet data: {pet_info}"
                )
            else:
                logger.error(f"[PET_AUTH] Pet {pet_id} NOT FOUND in database at all (checked with service role client)")
        except Exception as check_error:
            # If service role check fails, just log the original error
            logger.error(f"[PET_AUTH] Could not verify pet existence with service role: {type(check_error).__name__}: {check_error}", exc_info=True)
        
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pet not found or access denied"
        )
    
    return response.data[0]
