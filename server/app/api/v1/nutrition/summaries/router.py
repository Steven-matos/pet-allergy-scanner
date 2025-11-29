"""
Nutrition Summaries Sub-domain Router

Handles nutrition insights and multi-pet analytics.
Extracted from app.routers.nutrition for better organization.
"""

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from typing import List

from app.core.database import get_db
from app.models.nutrition.nutrition import (
    MultiPetNutritionInsights,
    DailyNutritionSummaryResponse
)
from app.models.core.user import UserResponse
from app.core.security.jwt_handler import get_current_user, security
from app.api.v1.dependencies import get_authenticated_supabase_client
from app.utils.logging_config import get_logger
from supabase import Client

logger = get_logger(__name__)
router = APIRouter(prefix="/summaries", tags=["nutrition-summaries"])


@router.get("/insights/multi-pet", response_model=MultiPetNutritionInsights)
async def get_multi_pet_insights(
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Get multi-pet nutrition insights for the current user
    
    Args:
        supabase: Authenticated Supabase client
        current_user: Current authenticated user
        
    Returns:
        Multi-pet nutrition insights
        
    Raises:
        HTTPException: If insights generation fails
    """
    try:
        # Get user's pets
        from app.shared.utils.async_supabase import execute_async
        pets_response = await execute_async(
            lambda: supabase.table("pets").select("*").eq("user_id", current_user.id).execute()
        )
        
        pets = pets_response.data if pets_response.data else []
        
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
        logger.error(f"Failed to generate multi-pet insights: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate multi-pet insights: {str(e)}"
        )


@router.get("/daily/{pet_id}", response_model=List[DailyNutritionSummaryResponse])
async def get_daily_nutrition_summaries(
    pet_id: str,
    days: int = 7,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Get daily nutrition summaries for a pet over specified days
    
    Args:
        pet_id: Pet ID
        days: Number of days to include (default: 7)
        supabase: Authenticated Supabase client
        current_user: Current authenticated user
        
    Returns:
        List of daily nutrition summaries
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id, supabase)
        
        # Get daily summaries (this would contain the actual summary logic)
        summaries = []  # Placeholder for actual summary generation
        
        return summaries
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get daily nutrition summaries: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get daily nutrition summaries: {str(e)}"
        )
