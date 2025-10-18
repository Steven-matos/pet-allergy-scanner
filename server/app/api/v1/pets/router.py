"""
Pet management router
"""

from fastapi import APIRouter, HTTPException, Depends, status
from fastapi.security import HTTPAuthorizationCredentials
from fastapi.responses import RedirectResponse
from typing import List
from app.models.pet import PetCreate, PetResponse, PetUpdate
from app.models.user import UserResponse
from app.core.security.jwt_handler import get_current_user, security
from app.database import get_supabase_client
from supabase import Client
from app.utils.logging_config import get_logger

router = APIRouter()
logger = get_logger(__name__)

@router.post("", response_model=PetResponse)
async def create_pet_no_slash(
    pet_data: PetCreate,
    current_user: UserResponse = Depends(get_current_user),
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """Create pet (without trailing slash)"""
    return await create_pet_with_slash(pet_data, current_user, credentials)

@router.post("/", response_model=PetResponse)
async def create_pet_with_slash(
    pet_data: PetCreate,
    current_user: UserResponse = Depends(get_current_user),
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """
    Create a new pet profile
    
    Creates a new pet profile for the authenticated user with species-specific validation
    """
    try:
        # Create authenticated Supabase client with user's JWT token
        from app.core.config import settings
        from supabase import create_client
        
        # Create an authenticated Supabase client using the JWT token
        supabase = create_client(
            settings.supabase_url,
            settings.supabase_key
        )
        
        # Set the session with the user's JWT token
        supabase.auth.set_session(credentials.credentials, "")
        
        # Validate species-specific requirements
        if pet_data.species == "cat" and pet_data.weight_kg and pet_data.weight_kg > 15:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cat weight seems unusually high. Please verify the weight."
            )
        
        if pet_data.species == "dog" and pet_data.weight_kg and pet_data.weight_kg > 100:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Dog weight seems unusually high. Please verify the weight."
            )
        
        # Create pet record
        pet_record = {
            "name": pet_data.name,
            "species": pet_data.species,
            "breed": pet_data.breed,
            "birthday": pet_data.birthday,
            "weight_kg": pet_data.weight_kg,
            "activity_level": pet_data.activity_level,
            "image_url": pet_data.image_url,
            "known_sensitivities": pet_data.known_sensitivities,
            "vet_name": pet_data.vet_name,
            "vet_phone": pet_data.vet_phone,
            "user_id": current_user.id
        }
        
        # Insert pet into database
        response = supabase.table("pets").insert(pet_record).execute()
        
        if not response.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create pet profile"
            )
        
        created_pet = response.data[0]
        
        return PetResponse(
            id=created_pet["id"],
            name=created_pet["name"],
            species=created_pet["species"],
            breed=created_pet.get("breed"),
            birthday=created_pet.get("birthday"),
            weight_kg=created_pet.get("weight_kg"),
            activity_level=created_pet.get("activity_level"),
            image_url=created_pet.get("image_url"),
            known_sensitivities=created_pet.get("known_sensitivities", []),
            vet_name=created_pet.get("vet_name"),
            vet_phone=created_pet.get("vet_phone"),
            user_id=created_pet["user_id"],
            created_at=created_pet["created_at"],
            updated_at=created_pet["updated_at"]
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating pet: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error creating pet profile"
        )

@router.get("/", response_model=List[PetResponse])
async def get_user_pets(
    current_user: UserResponse = Depends(get_current_user),
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """
    Get all pets for the current user
    
    Returns a list of all pet profiles belonging to the authenticated user
    """
    try:
        # Create authenticated Supabase client with user's JWT token
        from app.core.config import settings
        from supabase import create_client
        
        # Create an authenticated Supabase client using the JWT token
        supabase = create_client(
            settings.supabase_url,
            settings.supabase_key
        )
        
        # Set the session with the user's JWT token
        supabase.auth.set_session(credentials.credentials, "")
        
        # Get pets for the current user
        response = supabase.table("pets").select("*").eq("user_id", current_user.id).execute()
        
        if not response.data:
            return []
        
        pets = []
        for pet in response.data:
            pets.append(PetResponse(
                id=pet["id"],
                name=pet["name"],
                species=pet["species"],
                breed=pet.get("breed"),
                birthday=pet.get("birthday"),
                weight_kg=pet.get("weight_kg"),
                activity_level=pet.get("activity_level"),
                image_url=pet.get("image_url"),
                known_sensitivities=pet.get("known_sensitivities", []),
                vet_name=pet.get("vet_name"),
                vet_phone=pet.get("vet_phone"),
                user_id=pet["user_id"],
                created_at=pet["created_at"],
                updated_at=pet["updated_at"]
            ))
        
        return pets
        
    except Exception as e:
        logger.error(f"Error fetching pets: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error fetching pets"
        )

@router.get("/{pet_id}", response_model=PetResponse)
async def get_pet(
    pet_id: str,
    current_user: UserResponse = Depends(get_current_user),
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """
    Get a specific pet by ID
    
    Returns the pet profile if it belongs to the authenticated user
    """
    try:
        # Create authenticated Supabase client with user's JWT token
        from app.core.config import settings
        from supabase import create_client
        
        # Create an authenticated Supabase client using the JWT token
        supabase = create_client(
            settings.supabase_url,
            settings.supabase_key
        )
        
        # Set the session with the user's JWT token
        supabase.auth.set_session(credentials.credentials, "")
        
        # Get pet by ID and verify ownership
        response = supabase.table("pets").select("*").eq("id", pet_id).eq("user_id", current_user.id).execute()
        
        if not response.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Pet not found"
            )
        
        pet = response.data[0]
        
        return PetResponse(
            id=pet["id"],
            name=pet["name"],
            species=pet["species"],
            breed=pet.get("breed"),
            birthday=pet.get("birthday"),
            weight_kg=pet.get("weight_kg"),
            activity_level=pet.get("activity_level"),
            image_url=pet.get("image_url"),
            known_sensitivities=pet.get("known_sensitivities", []),
            vet_name=pet.get("vet_name"),
            vet_phone=pet.get("vet_phone"),
            user_id=pet["user_id"],
            created_at=pet["created_at"],
            updated_at=pet["updated_at"]
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching pet: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error fetching pet"
        )

@router.put("/{pet_id}", response_model=PetResponse)
async def update_pet(
    pet_id: str,
    pet_update: PetUpdate,
    current_user: UserResponse = Depends(get_current_user),
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """
    Update a pet profile
    
    Updates the pet profile if it belongs to the authenticated user
    """
    try:
        # Create authenticated Supabase client with user's JWT token
        from app.core.config import settings
        from supabase import create_client
        
        # Create an authenticated Supabase client using the JWT token
        supabase = create_client(
            settings.supabase_url,
            settings.supabase_key
        )
        
        # Set the session with the user's JWT token
        supabase.auth.set_session(credentials.credentials, "")
        
        # Verify pet exists and belongs to user
        existing_response = supabase.table("pets").select("id").eq("id", pet_id).eq("user_id", current_user.id).execute()
        
        if not existing_response.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Pet not found"
            )
        
        # Validate species-specific requirements for updates
        if pet_update.species == "cat" and pet_update.weight_kg and pet_update.weight_kg > 15:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cat weight seems unusually high. Please verify the weight."
            )
        
        if pet_update.species == "dog" and pet_update.weight_kg and pet_update.weight_kg > 100:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Dog weight seems unusually high. Please verify the weight."
            )
        
        # Prepare update data
        update_data = pet_update.dict(exclude_unset=True)
        
        # Update pet
        response = supabase.table("pets").update(update_data).eq("id", pet_id).eq("user_id", current_user.id).execute()
        
        if not response.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to update pet profile"
            )
        
        updated_pet = response.data[0]
        
        return PetResponse(
            id=updated_pet["id"],
            name=updated_pet["name"],
            species=updated_pet["species"],
            breed=updated_pet.get("breed"),
            birthday=updated_pet.get("birthday"),
            weight_kg=updated_pet.get("weight_kg"),
            activity_level=updated_pet.get("activity_level"),
            image_url=updated_pet.get("image_url"),
            known_sensitivities=updated_pet.get("known_sensitivities", []),
            vet_name=updated_pet.get("vet_name"),
            vet_phone=updated_pet.get("vet_phone"),
            user_id=updated_pet["user_id"],
            created_at=updated_pet["created_at"],
            updated_at=updated_pet["updated_at"]
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating pet: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error updating pet profile"
        )

@router.delete("/{pet_id}")
async def delete_pet(
    pet_id: str,
    current_user: UserResponse = Depends(get_current_user),
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """
    Delete a pet profile
    
    Deletes the pet profile if it belongs to the authenticated user
    """
    try:
        # Create authenticated Supabase client with user's JWT token
        from app.core.config import settings
        from supabase import create_client
        
        # Create an authenticated Supabase client using the JWT token
        supabase = create_client(
            settings.supabase_url,
            settings.supabase_key
        )
        
        # Set the session with the user's JWT token
        supabase.auth.set_session(credentials.credentials, "")
        
        # Verify pet exists and belongs to user
        existing_response = supabase.table("pets").select("id").eq("id", pet_id).eq("user_id", current_user.id).execute()
        
        if not existing_response.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Pet not found"
            )
        
        # Delete pet
        response = supabase.table("pets").delete().eq("id", pet_id).eq("user_id", current_user.id).execute()
        
        return {"message": "Pet profile deleted successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting pet: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error deleting pet profile"
        )
