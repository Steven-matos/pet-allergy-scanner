"""
Pet management router
"""

from fastapi import APIRouter, HTTPException, Depends, status
from fastapi.security import HTTPAuthorizationCredentials
from fastapi.responses import RedirectResponse
from typing import List
from app.models.core.pet import PetCreate, PetResponse, PetUpdate
from app.models.core.user import UserResponse
from app.core.security.jwt_handler import get_current_user, security
from app.api.v1.dependencies import get_authenticated_supabase_client
from app.core.database import get_supabase_client
from supabase import Client
from app.utils.logging_config import get_logger

# Import centralized services
from app.shared.services.database_operation_service import DatabaseOperationService
from app.shared.services.response_model_service import ResponseModelService
from app.shared.services.response_utils import handle_empty_response
from app.shared.services.validation_service import ValidationService
from app.shared.services.data_transformation_service import DataTransformationService
from app.shared.decorators.error_handler import handle_errors

router = APIRouter()
logger = get_logger(__name__)

@router.post("", response_model=PetResponse)
async def create_pet_no_slash(
    pet_data: PetCreate,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """Create pet (without trailing slash)"""
    return await create_pet_with_slash(pet_data, current_user, supabase)

@router.post("/", response_model=PetResponse)
@handle_errors("create_pet")
async def create_pet_with_slash(
    pet_data: PetCreate,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Create a new pet profile
    
    Creates a new pet profile for the authenticated user with species-specific validation
    """
    # Validate species-specific requirements using centralized validation service
    ValidationService.validate_pet_weight(pet_data.species, pet_data.weight_kg)
    
    # Prepare pet record using data transformation service
    pet_record = DataTransformationService.model_to_dict(pet_data, exclude_none=True)
    pet_record["user_id"] = current_user.id
    
    # Handle date serialization
    if "birthday" in pet_record and pet_record["birthday"] is not None:
        if hasattr(pet_record["birthday"], "isoformat"):
            pet_record["birthday"] = pet_record["birthday"].isoformat()
    
    # Handle enum serialization
    if "activity_level" in pet_record and hasattr(pet_record["activity_level"], "value"):
        pet_record["activity_level"] = pet_record["activity_level"].value
    
    # Insert pet into database using centralized service
    db_service = DatabaseOperationService(supabase)
    created_pet = await db_service.insert_with_timestamps("pets", pet_record)
    
    # Convert to response model using centralized service
    return ResponseModelService.convert_to_model(created_pet, PetResponse)

@router.get("/", response_model=List[PetResponse])
@handle_errors("get_user_pets")
async def get_user_pets(
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Get all pets for the current user
    
    Returns a list of all pet profiles belonging to the authenticated user
    """
    # Get pets for the current user using query builder
    from app.shared.services.query_builder_service import QueryBuilderService
    
    query_builder = QueryBuilderService(supabase, "pets")
    result = await query_builder.with_filters({"user_id": current_user.id}).execute()
    
    # Handle empty response using centralized utility
    pets_data = handle_empty_response(result["data"])
    
    # Convert to response models using centralized service
    return ResponseModelService.convert_list_to_models(pets_data, PetResponse)

@router.get("/mobile", response_model=List[dict])
@handle_errors("get_user_pets_mobile")
async def get_user_pets_mobile(
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Mobile-optimized endpoint to get pets with minimal fields
    
    Returns only essential fields (id, name, species, image_url) for faster
    loading on mobile devices with limited bandwidth.
    """
    from app.shared.services.query_builder_service import QueryBuilderService
    
    # Select only essential fields for mobile
    query_builder = QueryBuilderService(
        supabase, 
        "pets",
        default_columns=["id", "name", "species", "image_url", "created_at"]
    )
    result = await query_builder.with_filters({"user_id": current_user.id}).execute()
    
    # Handle empty response
    pets_data = handle_empty_response(result["data"])
    
    # Return minimal data structure
    return pets_data

@router.get("/{pet_id}", response_model=PetResponse)
@handle_errors("get_pet")
async def get_pet(
    pet_id: str,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Get a specific pet by ID
    
    Returns the pet profile if it belongs to the authenticated user
    """
    # Get pet by ID and verify ownership using query builder
    from app.shared.services.query_builder_service import QueryBuilderService
    
    query_builder = QueryBuilderService(supabase, "pets")
    result = await query_builder.with_filters({
        "id": pet_id,
        "user_id": current_user.id
    }).execute()
    
    if not result["data"]:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pet not found"
        )
    
    # Convert to response model using centralized service
    return ResponseModelService.convert_to_model(result["data"][0], PetResponse)

@router.put("/{pet_id}", response_model=PetResponse)
@handle_errors("update_pet")
async def update_pet(
    pet_id: str,
    pet_update: PetUpdate,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Update a pet profile
    
    Updates the pet profile if it belongs to the authenticated user
    """
    # Verify pet exists and belongs to user
    from app.shared.services.query_builder_service import QueryBuilderService
    
    query_builder = QueryBuilderService(supabase, "pets")
    existing_result = await query_builder.with_filters({
        "id": pet_id,
        "user_id": current_user.id
    }).select(["id"]).execute()
    
    if not existing_result["data"]:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pet not found"
        )
        
        # Get existing pet to validate species-specific requirements
        from app.shared.services.query_builder_service import QueryBuilderService
        
        query_builder = QueryBuilderService(supabase, "pets")
        existing_result = await query_builder.select(["species"]).with_filters({
            "id": pet_id,
            "user_id": current_user.id
        }).execute()
        
        if existing_result["data"]:
            existing_species = existing_result["data"][0]["species"]
            # Validate species-specific requirements for updates using centralized validation
            ValidationService.validate_pet_weight(existing_species, pet_update.weight_kg)
        
        # Prepare update data using data transformation service
        update_data = DataTransformationService.model_to_dict(pet_update, exclude_none=True)
        
        # Convert date objects to strings for JSON serialization
        if 'birthday' in update_data and update_data['birthday'] is not None:
            if hasattr(update_data['birthday'], 'isoformat'):
                update_data['birthday'] = update_data['birthday'].isoformat()
        
        # Handle enum serialization
        if 'activity_level' in update_data and hasattr(update_data['activity_level'], 'value'):
            update_data['activity_level'] = update_data['activity_level'].value
        
        # Update pet using centralized service
        db_service = DatabaseOperationService(supabase)
        updated_pet = await db_service.update_with_timestamp("pets", pet_id, update_data)
        
        # Convert to response model using centralized service
        return ResponseModelService.convert_to_model(updated_pet, PetResponse)

@router.delete("/{pet_id}")
@handle_errors("delete_pet")
async def delete_pet(
    pet_id: str,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Delete a pet profile
    
    Deletes the pet profile if it belongs to the authenticated user
    """
    # Verify pet exists and belongs to user
    from app.shared.services.query_builder_service import QueryBuilderService
    
    query_builder = QueryBuilderService(supabase, "pets")
    existing_result = await query_builder.select(["id"]).with_filters({
        "id": pet_id,
        "user_id": current_user.id
    }).execute()
    
    if not existing_result["data"]:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pet not found"
        )
    
    # Delete pet using centralized service
    db_service = DatabaseOperationService(supabase)
    await db_service.delete_record("pets", pet_id)
    
    return {"message": "Pet profile deleted successfully"}
