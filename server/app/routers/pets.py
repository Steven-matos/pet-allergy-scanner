"""
Pet management router
"""

from fastapi import APIRouter, HTTPException, Depends, status
from typing import List
from app.models.pet import PetCreate, PetResponse, PetUpdate
from app.routers.auth import get_current_user
from app.database import get_supabase_client
from supabase import Client
import logging

router = APIRouter()
logger = logging.getLogger(__name__)

@router.post("/", response_model=PetResponse)
async def create_pet(
    pet_data: PetCreate,
    current_user: dict = Depends(get_current_user)
):
    """
    Create a new pet profile
    
    Creates a new pet profile for the authenticated user with species-specific validation
    """
    try:
        supabase = get_supabase_client()
        
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
            "age_months": pet_data.age_months,
            "weight_kg": pet_data.weight_kg,
            "known_allergies": pet_data.known_allergies,
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
            age_months=pet["age_months"],
            weight_kg=pet["weight_kg"],
            known_allergies=pet["known_allergies"],
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
async def get_user_pets(current_user: dict = Depends(get_current_user)):
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
                age_months=pet["age_months"],
                weight_kg=pet["weight_kg"],
                known_allergies=pet["known_allergies"],
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
    current_user: dict = Depends(get_current_user)
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
            age_months=pet["age_months"],
            weight_kg=pet["weight_kg"],
            known_allergies=pet["known_allergies"],
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
    current_user: dict = Depends(get_current_user)
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
        
        # Build update data
        update_data = {}
        if pet_update.name is not None:
            update_data["name"] = pet_update.name
        if pet_update.breed is not None:
            update_data["breed"] = pet_update.breed
        if pet_update.age_months is not None:
            update_data["age_months"] = pet_update.age_months
        if pet_update.weight_kg is not None:
            update_data["weight_kg"] = pet_update.weight_kg
        if pet_update.known_allergies is not None:
            update_data["known_allergies"] = pet_update.known_allergies
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
            age_months=pet["age_months"],
            weight_kg=pet["weight_kg"],
            known_allergies=pet["known_allergies"],
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
    current_user: dict = Depends(get_current_user)
):
    """
    Delete a pet profile
    
    Permanently deletes a pet profile and all associated data
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
