"""
Nutrition Analysis Sub-domain Router

Handles food analysis and nutrition compatibility assessment.
Extracted from app.routers.nutrition for better organization.
"""

from fastapi import APIRouter, Depends, HTTPException
from typing import List
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.nutrition import (
    FoodAnalysisCreate,
    FoodAnalysisResponse,
    NutritionCompatibilityResponse,
    NutritionAnalysisRequest
)
from app.models.user import UserResponse
from app.core.security.jwt_handler import get_current_user
# Removed unused imports: create_error_response, APIError

router = APIRouter(prefix="/analysis", tags=["nutrition-analysis"])


@router.post("/analyze", response_model=FoodAnalysisResponse)
async def analyze_food(
    analysis_request: NutritionAnalysisRequest,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Analyze food for nutritional content and pet compatibility
    
    Args:
        analysis_request: Food analysis request data
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        Food analysis results
        
    Raises:
        HTTPException: If analysis fails
    """
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(analysis_request.pet_id, current_user.id)
        
        # Create food analysis
        analysis_data = analysis_request.dict()
        analysis_data['user_id'] = current_user.id
        
        db_analysis = FoodAnalysisCreate(**analysis_data)
        db.add(db_analysis)
        db.commit()
        db.refresh(db_analysis)
        
        return FoodAnalysisResponse.from_orm(db_analysis)
        
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Failed to analyze food: {str(e)}"
        )


@router.get("/analyses/{pet_id}", response_model=List[FoodAnalysisResponse])
async def get_food_analyses(
    pet_id: str,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get food analyses for a pet
    
    Args:
        pet_id: Pet ID
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        List of food analyses for the pet
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id)
        
        # Get food analyses
        analyses = db.query(FoodAnalysisCreate).filter(
            FoodAnalysisCreate.pet_id == pet_id,
            FoodAnalysisCreate.user_id == current_user.id
        ).all()
        
        return [FoodAnalysisResponse.from_orm(analysis) for analysis in analyses]
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get food analyses: {str(e)}"
        )


@router.post("/compatibility", response_model=NutritionCompatibilityResponse)
async def assess_nutrition_compatibility(
    compatibility_request: dict,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Assess nutrition compatibility between food and pet
    
    Args:
        compatibility_request: Compatibility assessment data
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        Nutrition compatibility assessment
        
    Raises:
        HTTPException: If assessment fails
    """
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(compatibility_request['pet_id'], current_user.id)
        
        # Perform compatibility assessment
        # This would contain the actual compatibility logic
        compatibility_result = {
            "compatibility_level": "compatible",
            "score": 85,
            "recommendations": ["Good nutritional match"],
            "warnings": []
        }
        
        return NutritionCompatibilityResponse(**compatibility_result)
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to assess nutrition compatibility: {str(e)}"
        )


@router.get("/food-analysis/{food_analysis_id}", response_model=FoodAnalysisResponse)
async def get_food_analysis(
    food_analysis_id: str,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get specific food analysis by ID
    
    Args:
        food_analysis_id: Food analysis ID
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        Food analysis details
        
    Raises:
        HTTPException: If analysis not found or user not authorized
    """
    try:
        # Get food analysis
        analysis = db.query(FoodAnalysisCreate).filter(
            FoodAnalysisCreate.id == food_analysis_id,
            FoodAnalysisCreate.user_id == current_user.id
        ).first()
        
        if not analysis:
            raise HTTPException(
                status_code=404,
                detail="Food analysis not found"
            )
        
        return FoodAnalysisResponse.from_orm(analysis)
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get food analysis: {str(e)}"
        )
