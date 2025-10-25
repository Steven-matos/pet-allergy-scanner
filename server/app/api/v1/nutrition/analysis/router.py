"""
Nutrition Analysis Sub-domain Router

Handles food analysis and nutrition compatibility assessment.
Extracted from app.routers.nutrition for better organization.
"""

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from typing import List
import uuid
from datetime import datetime

from app.database import get_db
from app.models.nutrition import (
    FoodAnalysisCreate,
    FoodAnalysisResponse,
    NutritionCompatibilityResponse,
    NutritionAnalysisRequest
)
from app.models.user import UserResponse
from app.core.security.jwt_handler import get_current_user, security
from app.utils.logging_config import get_logger

logger = get_logger(__name__)
router = APIRouter(prefix="/analysis", tags=["nutrition-analysis"])


@router.post("/analyze", response_model=FoodAnalysisResponse)
async def analyze_food(
    analysis_request: NutritionAnalysisRequest,
    current_user: UserResponse = Depends(get_current_user),
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """
    Analyze food for nutritional content and pet compatibility
    
    Args:
        analysis_request: Food analysis request data
        supabase: Supabase client
        current_user: Current authenticated user
        
    Returns:
        Food analysis results
        
    Raises:
        HTTPException: If analysis fails
    """
    try:
        # Create authenticated Supabase client
        from app.core.config import settings
        from supabase import create_client
        
        supabase = create_client(
            settings.supabase_url,
            settings.supabase_key
        )
        supabase.auth.set_session(credentials.credentials, "")
        
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(analysis_request.pet_id, current_user.id, supabase)
        
        # Create food analysis
        analysis_data = analysis_request.dict()
        analysis_data['user_id'] = current_user.id
        analysis_data['id'] = str(uuid.uuid4())
        
        # Insert into database
        response = supabase.table("food_analyses").insert(analysis_data).execute()
        
        if not response.data:
            raise HTTPException(status_code=500, detail="Failed to create food analysis")
        
        created_analysis = response.data[0]
        return FoodAnalysisResponse(**created_analysis)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to analyze food: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to analyze food: {str(e)}"
        )


@router.get("/analyses/{pet_id}", response_model=List[FoodAnalysisResponse])
async def get_food_analyses(
    pet_id: str,
    current_user: UserResponse = Depends(get_current_user),
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """
    Get food analyses for a pet
    
    Args:
        pet_id: Pet ID
        supabase: Supabase client
        current_user: Current authenticated user
        
    Returns:
        List of food analyses for the pet
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        # Create authenticated Supabase client
        from app.core.config import settings
        from supabase import create_client
        
        supabase = create_client(
            settings.supabase_url,
            settings.supabase_key
        )
        supabase.auth.set_session(credentials.credentials, "")
        
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id, supabase)
        
        # Get food analyses
        response = supabase.table("food_analyses").select("*").eq("pet_id", pet_id).eq("user_id", current_user.id).execute()
        
        if not response.data:
            return []
        
        return [FoodAnalysisResponse(**analysis) for analysis in response.data]
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get food analyses: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get food analyses: {str(e)}"
        )


@router.post("/compatibility", response_model=NutritionCompatibilityResponse)
async def assess_nutrition_compatibility(
    compatibility_request: dict,
    current_user: UserResponse = Depends(get_current_user),
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """
    Assess nutrition compatibility between food and pet
    
    Args:
        compatibility_request: Compatibility assessment data
        supabase: Supabase client
        current_user: Current authenticated user
        
    Returns:
        Nutrition compatibility assessment
        
    Raises:
        HTTPException: If assessment fails
    """
    try:
        # Create authenticated Supabase client
        from app.core.config import settings
        from supabase import create_client
        
        supabase = create_client(
            settings.supabase_url,
            settings.supabase_key
        )
        supabase.auth.set_session(credentials.credentials, "")
        
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(compatibility_request['pet_id'], current_user.id, supabase)
        
        # Perform compatibility assessment
        # This would contain the actual compatibility logic
        compatibility_result = {
            "compatibility_level": "compatible",
            "score": 85,
            "recommendations": ["Good nutritional match"],
            "warnings": []
        }
        
        return NutritionCompatibilityResponse(**compatibility_result)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to assess nutrition compatibility: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to assess nutrition compatibility: {str(e)}"
        )


@router.get("/food-analysis/{food_analysis_id}", response_model=FoodAnalysisResponse)
async def get_food_analysis(
    food_analysis_id: str,
    supabase = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get specific food analysis by ID
    
    Args:
        food_analysis_id: Food analysis ID
        supabase: Supabase client
        current_user: Current authenticated user
        
    Returns:
        Food analysis details
        
    Raises:
        HTTPException: If analysis not found or user not authorized
    """
    try:
        # Get food analysis
        response = supabase.table("food_analyses").select("*").eq("id", food_analysis_id).eq("user_id", current_user.id).limit(1).execute()
        
        if not response.data:
            raise HTTPException(
                status_code=404,
                detail="Food analysis not found"
            )
        
        return FoodAnalysisResponse(**response.data[0])
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get food analysis: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get food analysis: {str(e)}"
        )
