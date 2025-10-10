"""
Nutrition Summaries Sub-domain Router

Handles nutrition insights and multi-pet analytics.
Extracted from app.routers.nutrition for better organization.
"""

from fastapi import APIRouter, Depends, HTTPException
from typing import List
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.nutrition import (
    MultiPetNutritionInsights,
    DailyNutritionSummaryResponse
)
from app.models.user import UserResponse
from app.core.security.jwt_handler import get_current_user
# Removed unused imports: create_error_response, APIError

router = APIRouter(prefix="/summaries", tags=["nutrition-summaries"])


@router.get("/insights/multi-pet", response_model=MultiPetNutritionInsights)
async def get_multi_pet_insights(
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get multi-pet nutrition insights for the current user
    
    Args:
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        Multi-pet nutrition insights
        
    Raises:
        HTTPException: If insights generation fails
    """
    try:
        # Get user's pets
        from app.models.pet import PetResponse
        pets = db.query(PetResponse).filter(
            PetResponse.user_id == current_user.id
        ).all()
        
        if not pets:
            return MultiPetNutritionInsights(
                total_pets=0,
                average_nutrition_score=0,
                insights=[],
                recommendations=[]
            )
        
        # Generate insights (this would contain the actual analytics logic)
        insights = {
            "total_pets": len(pets),
            "average_nutrition_score": 85,
            "insights": [
                "All pets are meeting their nutritional requirements",
                "Consider rotating protein sources for variety"
            ],
            "recommendations": [
                "Monitor weight trends monthly",
                "Schedule annual nutrition review"
            ]
        }
        
        return MultiPetNutritionInsights(**insights)
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate multi-pet insights: {str(e)}"
        )


@router.get("/daily/{pet_id}", response_model=List[DailyNutritionSummaryResponse])
async def get_daily_nutrition_summaries(
    pet_id: str,
    days: int = 7,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get daily nutrition summaries for a pet over specified days
    
    Args:
        pet_id: Pet ID
        days: Number of days to include (default: 7)
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        List of daily nutrition summaries
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id)
        
        # Get daily summaries (this would contain the actual summary logic)
        summaries = []  # Placeholder for actual summary generation
        
        return summaries
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get daily nutrition summaries: {str(e)}"
        )
