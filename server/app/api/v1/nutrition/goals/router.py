"""
Nutrition Goals Sub-domain Router

Handles calorie goals and nutrition targets.
Extracted from app.routers.nutrition for better organization.
"""

from fastapi import APIRouter, Depends, HTTPException
from typing import List, Optional
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.calorie_goals import (
    CalorieGoalCreate,
    CalorieGoalResponse,
    CalorieGoalUpdate
)
from app.models.user import UserResponse
from app.core.security.jwt_handler import get_current_user
# Removed unused imports: create_error_response, APIError

router = APIRouter(prefix="/goals", tags=["nutrition-goals"])


@router.post("/calorie-goals", response_model=CalorieGoalResponse)
async def create_calorie_goal(
    goal: CalorieGoalCreate,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Create a calorie goal for a pet
    
    Args:
        goal: Calorie goal data
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        Created calorie goal
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(goal.pet_id, current_user.id)
        
        # Create calorie goal
        goal_data = goal.dict()
        goal_data['user_id'] = current_user.id
        
        db_goal = CalorieGoalCreate(**goal_data)
        db.add(db_goal)
        db.commit()
        db.refresh(db_goal)
        
        return CalorieGoalResponse.from_orm(db_goal)
        
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Failed to create calorie goal: {str(e)}"
        )


@router.get("/calorie-goals", response_model=List[CalorieGoalResponse])
async def get_calorie_goals(
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get all calorie goals for the current user
    
    Args:
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        List of calorie goals
        
    Raises:
        HTTPException: If goals retrieval fails
    """
    try:
        # Get calorie goals
        goals = db.query(CalorieGoalCreate).filter(
            CalorieGoalCreate.user_id == current_user.id
        ).all()
        
        return [CalorieGoalResponse.from_orm(goal) for goal in goals]
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get calorie goals: {str(e)}"
        )


@router.get("/calorie-goals/{pet_id}", response_model=Optional[CalorieGoalResponse])
async def get_pet_calorie_goal(
    pet_id: str,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get calorie goal for a specific pet
    
    Args:
        pet_id: Pet ID
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        Calorie goal for the pet
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id)
        
        # Get calorie goal
        goal = db.query(CalorieGoalCreate).filter(
            CalorieGoalCreate.pet_id == pet_id,
            CalorieGoalCreate.user_id == current_user.id
        ).first()
        
        if goal:
            return CalorieGoalResponse.from_orm(goal)
        return None
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get calorie goal: {str(e)}"
        )


@router.delete("/calorie-goals/{pet_id}")
async def delete_calorie_goal(
    pet_id: str,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Delete calorie goal for a pet
    
    Args:
        pet_id: Pet ID
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        Success message
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id)
        
        # Delete calorie goal
        goal = db.query(CalorieGoalCreate).filter(
            CalorieGoalCreate.pet_id == pet_id,
            CalorieGoalCreate.user_id == current_user.id
        ).first()
        
        if goal:
            db.delete(goal)
            db.commit()
            return {"message": "Calorie goal deleted successfully"}
        else:
            raise HTTPException(
                status_code=404,
                detail="Calorie goal not found"
            )
        
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Failed to delete calorie goal: {str(e)}"
        )
