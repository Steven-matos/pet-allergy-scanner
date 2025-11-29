"""
Nutrition Goals Sub-domain Router

Handles calorie goals and nutrition targets.
Extracted from app.routers.nutrition for better organization.
"""

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from typing import List, Optional

from app.core.database import get_db
from app.models.nutrition.calorie_goals import (
    CalorieGoalCreate,
    CalorieGoalResponse,
    CalorieGoalUpdate
)
from app.models.core.user import UserResponse
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
router = APIRouter(prefix="/goals", tags=["nutrition-goals"])


@router.post("/calorie-goals", response_model=CalorieGoalResponse)
@handle_errors("create_calorie_goal")
async def create_calorie_goal(
    goal: CalorieGoalCreate,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Create a calorie goal for a pet
    
    Args:
        goal: Calorie goal data
        supabase: Authenticated Supabase client
        current_user: Current authenticated user
        
    Returns:
        Created calorie goal
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    # Verify pet ownership
    from app.shared.services.pet_authorization import verify_pet_ownership
    await verify_pet_ownership(goal.pet_id, current_user.id, supabase)
    
    # Create calorie goal using data transformation service
    goal_data = DataTransformationService.model_to_dict(goal)
    goal_data['id'] = IDGenerationService.generate_uuid()
    
    # Insert into database using centralized service (user_id not needed - RLS handles authorization via pet_id)
    db_service = DatabaseOperationService(supabase)
    created_goal = await db_service.insert_with_timestamps("calorie_goals", goal_data)
    
    # Convert to response model
    return ResponseModelService.convert_to_model(created_goal, CalorieGoalResponse)


@router.get("/calorie-goals", response_model=List[CalorieGoalResponse])
@handle_errors("get_calorie_goals")
async def get_calorie_goals(
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Get all calorie goals for the current user
    
    Args:
        supabase: Authenticated Supabase client
        current_user: Current authenticated user
        
    Returns:
        List of calorie goals
        
    Raises:
        HTTPException: If goals retrieval fails
    """
    # Get calorie goals using query builder (RLS automatically filters by pet ownership)
    query_builder = QueryBuilderService(supabase, "calorie_goals")
    result = await query_builder.execute()
    
    # Handle empty response
    goals_data = handle_empty_response(result["data"])
    
    # Convert to response models
    return ResponseModelService.convert_list_to_models(goals_data, CalorieGoalResponse)


@router.get("/calorie-goals/{pet_id}", response_model=Optional[CalorieGoalResponse])
@handle_errors("get_pet_calorie_goal")
async def get_pet_calorie_goal(
    pet_id: str,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Get calorie goal for a specific pet
    
    Args:
        pet_id: Pet ID
        supabase: Authenticated Supabase client
        current_user: Current authenticated user
        
    Returns:
        Calorie goal for the pet
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    # Verify pet ownership
    from app.shared.services.pet_authorization import verify_pet_ownership
    await verify_pet_ownership(pet_id, current_user.id, supabase)
    
    # Get calorie goal using query builder (RLS automatically ensures user owns the pet)
    query_builder = QueryBuilderService(supabase, "calorie_goals")
    result = await query_builder.with_filters({"pet_id": pet_id}).with_limit(1).execute()
    
    if result["data"]:
        return ResponseModelService.convert_to_model(result["data"][0], CalorieGoalResponse)
    return None


@router.delete("/calorie-goals/{pet_id}")
@handle_errors("delete_calorie_goal")
async def delete_calorie_goal(
    pet_id: str,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Delete calorie goal for a pet
    
    Args:
        pet_id: Pet ID
        supabase: Authenticated Supabase client
        current_user: Current authenticated user
        
    Returns:
        Success message
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    # Verify pet ownership
    from app.shared.services.pet_authorization import verify_pet_ownership
    await verify_pet_ownership(pet_id, current_user.id, supabase)
    
    # Check if calorie goal exists using query builder (RLS automatically ensures user owns the pet)
    query_builder = QueryBuilderService(supabase, "calorie_goals")
    check_result = await query_builder.select(["id"]).with_filters({"pet_id": pet_id}).with_limit(1).execute()
    
    if not check_result["data"]:
        raise HTTPException(
            status_code=404,
            detail="Calorie goal not found"
        )
    
    # Delete calorie goal using centralized service (RLS automatically ensures user owns the pet)
    db_service = DatabaseOperationService(supabase)
    # Note: Delete by pet_id requires a custom query, so we use the existing method
    # First get the goal ID
    goal_id = check_result["data"][0]["id"]
    await db_service.delete_record("calorie_goals", goal_id)
    
    return {"message": "Calorie goal deleted successfully"}
