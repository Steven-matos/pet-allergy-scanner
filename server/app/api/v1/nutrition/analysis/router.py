"""
Nutrition Analysis Sub-domain Router

Handles food analysis and nutrition compatibility assessment.
Extracted from app.routers.nutrition for better organization.
"""

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from typing import List
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
from app.api.v1.dependencies import get_authenticated_supabase_client
from app.utils.logging_config import get_logger
from supabase import Client

# Import centralized services
from app.shared.services.database_operation_service import DatabaseOperationService
from app.shared.services.response_model_service import ResponseModelService
from app.shared.services.response_utils import handle_empty_response
from app.shared.services.query_builder_service import QueryBuilderService
from app.shared.services.data_transformation_service import DataTransformationService
from app.shared.services.id_generation_service import IDGenerationService
from app.shared.decorators.error_handler import handle_errors

logger = get_logger(__name__)
router = APIRouter(prefix="/analysis", tags=["nutrition-analysis"])


@router.post("/analyze", response_model=FoodAnalysisResponse)
@handle_errors("analyze_food")
async def analyze_food(
    analysis_request: NutritionAnalysisRequest,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Analyze food for nutritional content and pet compatibility
    
    Args:
        analysis_request: Food analysis request data
        supabase: Authenticated Supabase client
        current_user: Current authenticated user
        
    Returns:
        Food analysis results
        
    Raises:
        HTTPException: If analysis fails
    """
    # Verify pet ownership
    from app.shared.services.pet_authorization import verify_pet_ownership
    await verify_pet_ownership(analysis_request.pet_id, current_user.id, supabase)
    
    # Create food analysis using data transformation service
    analysis_data = DataTransformationService.model_to_dict(analysis_request)
    analysis_data['user_id'] = current_user.id
    analysis_data['id'] = IDGenerationService.generate_uuid()
    
    # Insert into database using centralized service
    db_service = DatabaseOperationService(supabase)
    created_analysis = await db_service.insert_with_timestamps("food_analyses", analysis_data)
    
    # Convert to response model
    return ResponseModelService.convert_to_model(created_analysis, FoodAnalysisResponse)


@router.get("/analyses/{pet_id}", response_model=List[FoodAnalysisResponse])
@handle_errors("get_food_analyses")
async def get_food_analyses(
    pet_id: str,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Get food analyses for a pet
    
    Args:
        pet_id: Pet ID
        supabase: Authenticated Supabase client
        current_user: Current authenticated user
        
    Returns:
        List of food analyses for the pet
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    # Verify pet ownership
    from app.shared.services.pet_authorization import verify_pet_ownership
    await verify_pet_ownership(pet_id, current_user.id, supabase)
    
    # Get food analyses using query builder
    query_builder = QueryBuilderService(supabase, "food_analyses")
    result = await query_builder.with_filters({
        "pet_id": pet_id,
        "user_id": current_user.id
    }).execute()
    
    # Handle empty response
    analyses_data = handle_empty_response(result["data"])
    
    # Convert to response models
    return ResponseModelService.convert_list_to_models(analyses_data, FoodAnalysisResponse)


@router.post("/compatibility", response_model=NutritionCompatibilityResponse)
@handle_errors("assess_nutrition_compatibility")
async def assess_nutrition_compatibility(
    compatibility_request: dict,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Assess nutrition compatibility between food and pet
    
    Args:
        compatibility_request: Compatibility assessment data
        supabase: Authenticated Supabase client
        current_user: Current authenticated user
        
    Returns:
        Nutrition compatibility assessment
        
    Raises:
        HTTPException: If assessment fails
    """
    try:
        
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
@handle_errors("get_food_analysis")
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
    # Get food analysis using query builder
    query_builder = QueryBuilderService(supabase, "food_analyses")
    result = await query_builder.with_filters({
        "id": food_analysis_id,
        "user_id": current_user.id
    }).with_limit(1).execute()
    
    if not result["data"]:
        raise HTTPException(
            status_code=404,
            detail="Food analysis not found"
        )
    
    return ResponseModelService.convert_to_model(result["data"][0], FoodAnalysisResponse)
