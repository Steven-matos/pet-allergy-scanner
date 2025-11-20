"""
Nutrition Requirements Sub-domain Router

Handles nutritional requirements for pets.
Extracted from app.routers.nutrition for better organization.
"""

from fastapi import APIRouter, Depends, HTTPException
from typing import List

from app.database import get_supabase_client
from app.models.nutrition import (
    NutritionalRequirementsCreate,
    NutritionalRequirementsResponse
)
from app.models.user import UserResponse
from app.core.security.jwt_handler import get_current_user
# Removed unused imports: create_error_response, APIError

router = APIRouter(prefix="/requirements", tags=["nutrition-requirements"])


@router.post("", response_model=NutritionalRequirementsResponse)
async def create_nutritional_requirements_no_slash(
    requirements: NutritionalRequirementsCreate,
    current_user: UserResponse = Depends(get_current_user)
):
    """Create nutritional requirements (without trailing slash)"""
    return await create_nutritional_requirements_with_slash(requirements, current_user)

@router.post("/", response_model=NutritionalRequirementsResponse)
async def create_nutritional_requirements_with_slash(
    requirements: NutritionalRequirementsCreate,
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Create or update nutritional requirements for a pet
    
    Args:
        requirements: Nutritional requirements data
        current_user: Current authenticated user
        
    Returns:
        Created nutritional requirements
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        supabase = get_supabase_client()
        
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(requirements.pet_id, current_user.id)
        
        # Create nutritional requirements
        # Note: nutritional_requirements table only has pet_id, not user_id
        # Authorization is handled via RLS policies checking pet ownership
        db_requirements = requirements.dict()
        
        # Upsert to nutritional_requirements table
        # Using pet_id as unique constraint (per schema: UNIQUE(pet_id))
        response = supabase.table("nutritional_requirements").upsert(
            db_requirements,
            on_conflict="pet_id"
        ).execute()
        
        if not response.data:
            raise HTTPException(
                status_code=400,
                detail="Failed to create nutritional requirements"
            )
        
        return NutritionalRequirementsResponse(**response.data[0])
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to create nutritional requirements: {str(e)}"
        )


@router.get("/{pet_id}", response_model=NutritionalRequirementsResponse)
async def get_nutritional_requirements(
    pet_id: str,
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get nutritional requirements for a pet
    
    Args:
        pet_id: Pet ID
        current_user: Current authenticated user
        
    Returns:
        Nutritional requirements for the pet
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        supabase = get_supabase_client()
        
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id)
        
        # Get nutritional requirements
        # Note: nutritional_requirements table only has pet_id, not user_id
        # Authorization is handled via RLS policies checking pet ownership
        response = supabase.table("nutritional_requirements").select("*").eq(
            "pet_id", pet_id
        ).execute()
        
        if not response.data:
            raise HTTPException(
                status_code=404,
                detail="Nutritional requirements not found"
            )
        
        return NutritionalRequirementsResponse(**response.data[0])
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get nutritional requirements: {str(e)}"
        )
