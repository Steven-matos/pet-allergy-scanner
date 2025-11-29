"""
Nutrition Requirements Sub-domain Router

Handles nutritional requirements for pets.
Extracted from app.routers.nutrition for better organization.
"""

from fastapi import APIRouter, Depends, HTTPException
from typing import List
from datetime import datetime
from app.shared.services.datetime_service import DateTimeService

from app.api.v1.dependencies import get_authenticated_supabase_client
from supabase import Client
from app.models.nutrition.nutrition import (
    NutritionalRequirementsCreate,
    NutritionalRequirementsResponse
)
from app.models.core.user import UserResponse
from app.models.core.pet import PetResponse
from app.core.security.jwt_handler import get_current_user

# Import centralized services
from app.shared.services.database_operation_service import DatabaseOperationService
from app.shared.services.response_model_service import ResponseModelService
from app.shared.services.query_builder_service import QueryBuilderService
from app.shared.services.data_transformation_service import DataTransformationService
from app.shared.services.id_generation_service import IDGenerationService
from app.shared.decorators.error_handler import handle_errors

router = APIRouter(prefix="/requirements", tags=["nutrition-requirements"])


@router.post("", response_model=NutritionalRequirementsResponse)
async def create_nutritional_requirements_no_slash(
    requirements: NutritionalRequirementsCreate,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """Create nutritional requirements (without trailing slash)"""
    return await create_nutritional_requirements_with_slash(requirements, current_user, supabase)

@router.post("/", response_model=NutritionalRequirementsResponse)
@handle_errors("create_nutritional_requirements")
async def create_nutritional_requirements_with_slash(
    requirements: NutritionalRequirementsCreate,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Create or update nutritional requirements for a pet
    
    Args:
        requirements: Nutritional requirements data
        current_user: Current authenticated user
        supabase: Authenticated Supabase client with session
        
    Returns:
        Created nutritional requirements
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    # Verify pet ownership
    from app.shared.services.pet_authorization import verify_pet_ownership
    await verify_pet_ownership(requirements.pet_id, current_user.id, supabase)
    
    # Create nutritional requirements using data transformation service
    # Note: nutritional_requirements table only has pet_id, not user_id
    # Authorization is handled via RLS policies checking pet ownership
    db_requirements = DataTransformationService.model_to_dict(requirements)
    
    # Upsert to nutritional_requirements table using centralized service
    # Using pet_id as unique constraint (per schema: UNIQUE(pet_id))
    db_service = DatabaseOperationService(supabase)
    result = await db_service.upsert_with_timestamps(
        "nutritional_requirements",
        db_requirements,
        conflict_column="pet_id"
    )
    
    # Convert to response model
    return ResponseModelService.convert_to_model(result, NutritionalRequirementsResponse)


@router.get("/{pet_id}", response_model=NutritionalRequirementsResponse)
@handle_errors("get_nutritional_requirements")
async def get_nutritional_requirements(
    pet_id: str,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Get nutritional requirements for a pet
    
    If no requirements exist in the database, returns default values (zeros)
    since no data has been provided yet for the pet.
    
    Args:
        pet_id: Pet ID
        current_user: Current authenticated user
        supabase: Authenticated Supabase client with session
        
    Returns:
        Nutritional requirements for the pet (from database or default zeros if not found)
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    # Verify pet ownership and get pet data
    from app.shared.services.pet_authorization import verify_pet_ownership
    pet_data = await verify_pet_ownership(pet_id, current_user.id, supabase)
    
    # Get nutritional requirements from database using query builder
    # Note: nutritional_requirements table only has pet_id, not user_id
    # Authorization is handled via RLS policies checking pet ownership
    query_builder = QueryBuilderService(supabase, "nutritional_requirements")
    result = await query_builder.with_filters({"pet_id": pet_id}).execute()
        
    # If requirements exist, return them
    if result["data"]:
        return ResponseModelService.convert_to_model(result["data"][0], NutritionalRequirementsResponse)
    
    # No requirements found - return default/empty values (zeros) since no data has been provided yet
    pet = ResponseModelService.convert_to_model(pet_data, PetResponse)
    
    # Get life stage and activity level from pet's profile
    # life_stage is a computed property that always returns a value (defaults to ADULT if no birthday)
    # effective_activity_level always returns a value (defaults to MODERATE if not set)
    life_stage = pet.life_stage.value
    activity_level = pet.effective_activity_level.value
    
    # Return default requirements with zeros (no data provided yet)
    calculated_at = DateTimeService.now()
    
    return NutritionalRequirementsResponse(
        id=IDGenerationService.generate_uuid(),  # Temporary ID for response
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
