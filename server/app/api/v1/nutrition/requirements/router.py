"""
Nutrition Requirements Sub-domain Router

Handles nutritional requirements for pets.
Extracted from app.routers.nutrition for better organization.
"""

from fastapi import APIRouter, Depends, HTTPException
from typing import List
from datetime import datetime
import uuid

from app.database import get_supabase_client
from app.models.nutrition import (
    NutritionalRequirementsCreate,
    NutritionalRequirementsResponse
)
from app.models.user import UserResponse
from app.models.pet import PetResponse
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
    
    If no requirements exist in the database, returns default values (zeros)
    since no data has been provided yet for the pet.
    
    Args:
        pet_id: Pet ID
        current_user: Current authenticated user
        
    Returns:
        Nutritional requirements for the pet (from database or default zeros if not found)
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        supabase = get_supabase_client()
        
        # Verify pet ownership and get pet data
        from app.shared.services.pet_authorization import verify_pet_ownership
        pet_data = await verify_pet_ownership(pet_id, current_user.id)
        
        # Get nutritional requirements from database
        # Note: nutritional_requirements table only has pet_id, not user_id
        # Authorization is handled via RLS policies checking pet ownership
        response = supabase.table("nutritional_requirements").select("*").eq(
            "pet_id", pet_id
        ).execute()
        
        # If requirements exist, return them
        if response.data:
            return NutritionalRequirementsResponse(**response.data[0])
        
        # No requirements found - return default/empty values (zeros) since no data has been provided yet
        pet = PetResponse(
            id=pet_data["id"],
            user_id=pet_data["user_id"],
            name=pet_data["name"],
            species=pet_data["species"],
            breed=pet_data.get("breed"),
            birthday=pet_data.get("birthday"),
            weight_kg=pet_data.get("weight_kg"),
            activity_level=pet_data.get("activity_level"),
            image_url=pet_data.get("image_url"),
            known_sensitivities=pet_data.get("known_sensitivities", []),
            vet_name=pet_data.get("vet_name"),
            vet_phone=pet_data.get("vet_phone"),
            created_at=pet_data["created_at"],
            updated_at=pet_data["updated_at"]
        )
        
        # Get life stage and activity level from pet's profile
        # life_stage is a computed property that always returns a value (defaults to ADULT if no birthday)
        # effective_activity_level always returns a value (defaults to MODERATE if not set)
        life_stage = pet.life_stage.value
        activity_level = pet.effective_activity_level.value
        
        # Return default requirements with zeros (no data provided yet)
        calculated_at = datetime.utcnow()
        
        return NutritionalRequirementsResponse(
            id=str(uuid.uuid4()),  # Temporary ID for response
            pet_id=pet_id,
            daily_calories=0.0,  # No data provided yet
            protein_percentage=0.0,  # No data provided yet
            fat_percentage=0.0,  # No data provided yet
            fiber_percentage=0.0,  # No data provided yet
            moisture_percentage=0.0,  # No data provided yet
            life_stage=life_stage,
            activity_level=activity_level,
            calculated_at=calculated_at,
            created_at=calculated_at,
            updated_at=calculated_at
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get nutritional requirements: {str(e)}"
        )
