"""
Nutrition Goals Sub-domain Router

Handles calorie goals and nutrition targets.
Extracted from app.routers.nutrition for better organization.
"""

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from typing import List, Optional
import uuid

from app.database import get_db
from app.models.calorie_goals import (
    CalorieGoalCreate,
    CalorieGoalResponse,
    CalorieGoalUpdate
)
from app.models.user import UserResponse
from app.core.security.jwt_handler import get_current_user, security
from app.api.v1.dependencies import get_authenticated_supabase_client
from app.utils.logging_config import get_logger
from supabase import Client

logger = get_logger(__name__)
router = APIRouter(prefix="/goals", tags=["nutrition-goals"])


@router.post("/calorie-goals", response_model=CalorieGoalResponse)
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
    try:
        
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(goal.pet_id, current_user.id, supabase)
        
        # Create calorie goal
        goal_data = goal.model_dump()
        goal_data['id'] = str(uuid.uuid4())
        
        # Insert into database (user_id not needed - RLS handles authorization via pet_id)
        response = supabase.table("calorie_goals").insert(goal_data).execute()
        
        if not response.data:
            raise HTTPException(status_code=500, detail="Failed to create calorie goal")
        
        created_goal = response.data[0]
        return CalorieGoalResponse(**created_goal)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to create calorie goal: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to create calorie goal: {str(e)}"
        )


@router.get("/calorie-goals", response_model=List[CalorieGoalResponse])
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
    try:
        
        # Get calorie goals (RLS automatically filters by pet ownership)
        response = supabase.table("calorie_goals").select("*").execute()
        
        if not response.data:
            return []
        
        return [CalorieGoalResponse(**goal) for goal in response.data]
        
    except Exception as e:
        logger.error(f"Failed to get calorie goals: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get calorie goals: {str(e)}"
        )


@router.get("/calorie-goals/{pet_id}", response_model=Optional[CalorieGoalResponse])
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
    try:
        
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id, supabase)
        
        # Get calorie goal (RLS automatically ensures user owns the pet)
        response = supabase.table("calorie_goals").select("*").eq("pet_id", pet_id).limit(1).execute()
        
        if response.data:
            return CalorieGoalResponse(**response.data[0])
        return None
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get calorie goal: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get calorie goal: {str(e)}"
        )


@router.delete("/calorie-goals/{pet_id}")
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
    try:
        
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id, supabase)
        
        # Check if calorie goal exists (RLS automatically ensures user owns the pet)
        check_response = supabase.table("calorie_goals").select("id").eq("pet_id", pet_id).limit(1).execute()
        
        if not check_response.data:
            raise HTTPException(
                status_code=404,
                detail="Calorie goal not found"
            )
        
        # Delete calorie goal (RLS automatically ensures user owns the pet)
        supabase.table("calorie_goals").delete().eq("pet_id", pet_id).execute()
        
        return {"message": "Calorie goal deleted successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to delete calorie goal: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to delete calorie goal: {str(e)}"
        )
