"""
Pet management router
"""

from fastapi import APIRouter, HTTPException, Depends, status
from fastapi.security import HTTPAuthorizationCredentials
from typing import List
from app.models.pet import PetCreate, PetResponse, PetUpdate
from app.models.user import UserResponse
from app.core.security.jwt_handler import get_current_user, security
from app.database import get_supabase_client
from supabase import Client
from app.utils.logging_config import get_logger

router = APIRouter()
logger = get_logger(__name__)

@router.post("/", response_model=PetResponse)
async def create_pet(
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
            "user_id": current_user.id,
            "name": pet_data.name,
            "species": pet_data.species.value,
            "breed": pet_data.breed,
            "birthday": pet_data.birthday.isoformat() if pet_data.birthday else None,
            "weight_kg": pet_data.weight_kg,
            "image_url": pet_data.image_url,
            "known_sensitivities": pet_data.known_sensitivities,
            "vet_name": pet_data.vet_name,
            "vet_phone": pet_data.vet_phone
        }
        
        response = supabase.table("pets").insert(pet_record).execute()
        
        if not response.data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to create pet profile"
            )
        
        pet = response.data[0]
        return PetResponse(
            id=pet["id"],
            user_id=pet["user_id"],
            name=pet["name"],
            species=pet["species"],
            breed=pet["breed"],
            birthday=pet["birthday"],
            weight_kg=pet["weight_kg"],
            image_url=pet.get("image_url"),
            known_sensitivities=pet["known_sensitivities"],
            vet_name=pet["vet_name"],
            vet_phone=pet["vet_phone"],
            created_at=pet["created_at"],
            updated_at=pet["updated_at"]
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Create pet error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to create pet profile"
        )

@router.get("/", response_model=List[PetResponse])
async def get_user_pets(current_user: UserResponse = Depends(get_current_user)):
    """
    Get all pets for the current user
    
    Returns a list of all pet profiles belonging to the authenticated user
    """
    try:
        supabase = get_supabase_client()
        
        response = supabase.table("pets").select("*").eq("user_id", current_user.id).execute()
        
        pets = []
        for pet in response.data:
            pets.append(PetResponse(
                id=pet["id"],
                user_id=pet["user_id"],
                name=pet["name"],
                species=pet["species"],
                breed=pet["breed"],
                birthday=pet["birthday"],
                weight_kg=pet["weight_kg"],
                image_url=pet.get("image_url"),
                known_sensitivities=pet["known_sensitivities"],
                vet_name=pet["vet_name"],
                vet_phone=pet["vet_phone"],
                created_at=pet["created_at"],
                updated_at=pet["updated_at"]
            ))
        
        return pets
        
    except Exception as e:
        logger.error(f"Get pets error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to retrieve pet profiles"
        )

@router.get("/{pet_id}", response_model=PetResponse)
async def get_pet(
    pet_id: str,
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get a specific pet profile
    
    Returns detailed information for a specific pet profile
    """
    try:
        supabase = get_supabase_client()
        
        # Verify pet belongs to user
        response = supabase.table("pets").select("*").eq("id", pet_id).eq("user_id", current_user.id).execute()
        
        if not response.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Pet profile not found"
            )
        
        pet = response.data[0]
        return PetResponse(
            id=pet["id"],
            user_id=pet["user_id"],
            name=pet["name"],
            species=pet["species"],
            breed=pet["breed"],
            birthday=pet["birthday"],
            weight_kg=pet["weight_kg"],
            image_url=pet.get("image_url"),
            known_sensitivities=pet["known_sensitivities"],
            vet_name=pet["vet_name"],
            vet_phone=pet["vet_phone"],
            created_at=pet["created_at"],
            updated_at=pet["updated_at"]
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Get pet error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to retrieve pet profile"
        )

@router.put("/{pet_id}", response_model=PetResponse)
async def update_pet(
    pet_id: str,
    pet_update: PetUpdate,
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Update a pet profile
    
    Updates an existing pet profile with new information
    """
    try:
        supabase = get_supabase_client()
        
        # Verify pet belongs to user
        existing_pet = supabase.table("pets").select("*").eq("id", pet_id).eq("user_id", current_user.id).execute()
        
        if not existing_pet.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Pet profile not found"
            )
        
        # Get current pet data to check for existing image
        current_pet_data = existing_pet.data[0]
        current_image_url = current_pet_data.get("image_url")
        
        # Build update data
        update_data = {}
        if pet_update.name is not None:
            update_data["name"] = pet_update.name
        if pet_update.breed is not None:
            update_data["breed"] = pet_update.breed
        if pet_update.birthday is not None:
            update_data["birthday"] = pet_update.birthday.isoformat()
        if pet_update.weight_kg is not None:
            update_data["weight_kg"] = pet_update.weight_kg
        if pet_update.image_url is not None:
            # Delete old image from storage if it exists and is different from new one
            if current_image_url and current_image_url != pet_update.image_url:
                if "storage/v1/object/public/pet-images/" in current_image_url:
                    try:
                        # Extract the storage path from the full URL
                        storage_path = current_image_url.split("/storage/v1/object/public/pet-images/")[-1]
                        supabase.storage.from_("pet-images").remove([storage_path])
                    except Exception as e:
                        logger.warning(f"Failed to delete old pet image: {e}")
            
            update_data["image_url"] = pet_update.image_url
        if pet_update.known_sensitivities is not None:
            update_data["known_sensitivities"] = pet_update.known_sensitivities
        if pet_update.vet_name is not None:
            update_data["vet_name"] = pet_update.vet_name
        if pet_update.vet_phone is not None:
            update_data["vet_phone"] = pet_update.vet_phone
        
        response = supabase.table("pets").update(update_data).eq("id", pet_id).execute()
        
        if not response.data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to update pet profile"
            )
        
        pet = response.data[0]
        return PetResponse(
            id=pet["id"],
            user_id=pet["user_id"],
            name=pet["name"],
            species=pet["species"],
            breed=pet["breed"],
            birthday=pet["birthday"],
            weight_kg=pet["weight_kg"],
            image_url=pet.get("image_url"),
            known_sensitivities=pet["known_sensitivities"],
            vet_name=pet["vet_name"],
            vet_phone=pet["vet_phone"],
            created_at=pet["created_at"],
            updated_at=pet["updated_at"]
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Update pet error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to update pet profile"
        )

@router.delete("/{pet_id}")
async def delete_pet(
    pet_id: str,
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Delete a pet profile
    
    Permanently deletes a pet profile and all associated data
    """
    try:
        supabase = get_supabase_client()
        
        # Verify pet belongs to user and get image URL for cleanup
        existing_pet = supabase.table("pets").select("*, image_url").eq("id", pet_id).eq("user_id", current_user.id).execute()
        
        if not existing_pet.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Pet profile not found"
            )
        
        pet_data = existing_pet.data[0]
        
        # Delete pet image from storage if it exists
        if pet_data.get("image_url"):
            image_url = pet_data["image_url"]
            if "storage/v1/object/public/pet-images/" in image_url:
                try:
                    # Extract the storage path from the full URL
                    storage_path = image_url.split("/storage/v1/object/public/pet-images/")[-1]
                    supabase.storage.from_("pet-images").remove([storage_path])
                    logger.info(f"Deleted pet image: {storage_path}")
                except Exception as e:
                    logger.warning(f"Failed to delete pet image {storage_path}: {e}")
        
        # Delete pet and associated scans
        supabase.table("scans").delete().eq("pet_id", pet_id).execute()
        supabase.table("pets").delete().eq("id", pet_id).execute()
        
        return {"message": "Pet profile deleted successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Delete pet error: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to delete pet profile"
        )
