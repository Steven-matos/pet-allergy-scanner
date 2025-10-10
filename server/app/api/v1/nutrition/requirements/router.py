"""
Nutrition Requirements Sub-domain Router

Handles nutritional requirements for pets.
Extracted from app.routers.nutrition for better organization.
"""

from fastapi import APIRouter, Depends, HTTPException
from typing import List
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.nutrition import (
    NutritionalRequirementsCreate,
    NutritionalRequirementsResponse
)
from app.models.user import UserResponse
from app.core.security.jwt_handler import get_current_user
# Removed unused imports: create_error_response, APIError

router = APIRouter(prefix="/requirements", tags=["nutrition-requirements"])


@router.post("/", response_model=NutritionalRequirementsResponse)
async def create_nutritional_requirements(
    requirements: NutritionalRequirementsCreate,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Create or update nutritional requirements for a pet
    
    Args:
        requirements: Nutritional requirements data
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        Created nutritional requirements
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(requirements.pet_id, current_user.id)
        
        # Create nutritional requirements
        db_requirements = requirements.dict()
        db_requirements['user_id'] = current_user.id
        
        db_requirements_obj = NutritionalRequirementsCreate(**db_requirements)
        db.add(db_requirements_obj)
        db.commit()
        db.refresh(db_requirements_obj)
        
        return NutritionalRequirementsResponse.from_orm(db_requirements_obj)
        
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Failed to create nutritional requirements: {str(e)}"
        )


@router.get("/{pet_id}", response_model=NutritionalRequirementsResponse)
async def get_nutritional_requirements(
    pet_id: str,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get nutritional requirements for a pet
    
    Args:
        pet_id: Pet ID
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        Nutritional requirements for the pet
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id)
        
        # Get nutritional requirements
        requirements = db.query(NutritionalRequirementsCreate).filter(
            NutritionalRequirementsCreate.pet_id == pet_id,
            NutritionalRequirementsCreate.user_id == current_user.id
        ).first()
        
        if not requirements:
            raise HTTPException(
                status_code=404,
                detail="Nutritional requirements not found"
            )
        
        return NutritionalRequirementsResponse.from_orm(requirements)
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get nutritional requirements: {str(e)}"
        )
