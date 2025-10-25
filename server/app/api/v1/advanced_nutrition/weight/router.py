"""
Advanced Nutrition - Weight Management Sub-domain

Handles weight tracking, goals, and weight-related analytics.
Extracted from advanced_nutrition.py for better organization.
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import List, Optional
from datetime import datetime, date, timedelta

from app.database import get_supabase_client
from app.models.advanced_nutrition import (
    PetWeightRecordCreate, PetWeightRecordResponse,
    PetWeightGoalCreate, PetWeightGoalResponse,
    WeightTrendAnalysis, WeightManagementDashboard
)
from app.models.user import User
from app.core.security.jwt_handler import get_current_user
from app.services.weight_tracking_service import WeightTrackingService

router = APIRouter(prefix="/weight", tags=["advanced-nutrition-weight"])

# Lazy service initialization
weight_service = None

def get_weight_service():
    """Get weight tracking service instance (lazy initialization)"""
    global weight_service
    if weight_service is None:
        weight_service = WeightTrackingService()
    return weight_service


@router.post("/record", response_model=PetWeightRecordResponse)
async def record_weight(
    weight_record: PetWeightRecordCreate,
    current_user: User = Depends(get_current_user)
):
    """
    Record a new weight measurement for a pet
    
    Args:
        weight_record: Weight record data
        current_user: Current authenticated user
        
    Returns:
        Created weight record
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        supabase = get_supabase_client()
        await verify_pet_ownership(weight_record.pet_id, current_user.id, supabase)
        
        # Create weight record
        service = get_weight_service()
        result = await service.record_weight(weight_record, current_user.id)
        
        return result
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to record weight: {str(e)}"
        )


@router.get("/history/{pet_id}", response_model=List[PetWeightRecordResponse])
async def get_weight_history(
    pet_id: str,
    days: int = Query(30, description="Number of days to retrieve"),
    current_user: User = Depends(get_current_user)
):
    """
    Get weight history for a pet
    
    Args:
        pet_id: Pet ID
        days: Number of days to retrieve
        current_user: Current authenticated user
        
    Returns:
        List of weight records
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        supabase = get_supabase_client()
        await verify_pet_ownership(pet_id, current_user.id, supabase)
        
        # Get weight history
        service = get_weight_service()
        history = await service.get_weight_history(pet_id, days)
        
        return history
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get weight history: {str(e)}"
        )


@router.post("/goals", response_model=PetWeightGoalResponse)
async def create_weight_goal(
    weight_goal: PetWeightGoalCreate,
    current_user: User = Depends(get_current_user)
):
    """
    Create a weight goal for a pet
    
    Args:
        weight_goal: Weight goal data
        current_user: Current authenticated user
        
    Returns:
        Created weight goal
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        supabase = get_supabase_client()
        await verify_pet_ownership(weight_goal.pet_id, current_user.id, supabase)
        
        # Create weight goal
        service = get_weight_service()
        result = await service.create_weight_goal(weight_goal, current_user.id)
        
        return result
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create weight goal: {str(e)}"
        )


@router.put("/goals", response_model=PetWeightGoalResponse)
async def upsert_weight_goal(
    weight_goal: PetWeightGoalCreate,
    current_user: User = Depends(get_current_user)
):
    """
    Create or update a weight goal for a pet
    
    Args:
        weight_goal: Weight goal data
        current_user: Current authenticated user
        
    Returns:
        Created or updated weight goal
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        supabase = get_supabase_client()
        await verify_pet_ownership(weight_goal.pet_id, current_user.id, supabase)
        
        # Upsert weight goal
        service = get_weight_service()
        result = await service.upsert_weight_goal(weight_goal, current_user.id)
        
        return result
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to upsert weight goal: {str(e)}"
        )


@router.get("/goals/{pet_id}/active", response_model=Optional[PetWeightGoalResponse])
async def get_active_weight_goal(
    pet_id: str,
    current_user: User = Depends(get_current_user)
):
    """
    Get active weight goal for a pet
    
    Args:
        pet_id: Pet ID
        current_user: Current authenticated user
        
    Returns:
        Active weight goal or None
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        supabase = get_supabase_client()
        await verify_pet_ownership(pet_id, current_user.id, supabase)
        
        # Get active weight goal
        service = get_weight_service()
        goal = await service.get_active_weight_goal(pet_id)
        
        return goal
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get active weight goal: {str(e)}"
        )


@router.get("/trend/{pet_id}", response_model=WeightTrendAnalysis)
async def analyze_weight_trend(
    pet_id: str,
    days: int = Query(30, description="Number of days to analyze"),
    current_user: User = Depends(get_current_user)
):
    """
    Analyze weight trend for a pet
    
    Args:
        pet_id: Pet ID
        days: Number of days to analyze
        current_user: Current authenticated user
        
    Returns:
        Weight trend analysis
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        supabase = get_supabase_client()
        await verify_pet_ownership(pet_id, current_user.id, supabase)
        
        # Analyze weight trend
        service = get_weight_service()
        analysis = await service.analyze_weight_trend(pet_id, days)
        
        return analysis
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to analyze weight trend: {str(e)}"
        )


@router.get("/dashboard/{pet_id}", response_model=WeightManagementDashboard)
async def get_weight_management_dashboard(
    pet_id: str,
    days: int = Query(30, description="Number of days for dashboard"),
    current_user: User = Depends(get_current_user)
):
    """
    Get weight management dashboard for a pet
    
    Args:
        pet_id: Pet ID
        days: Number of days for dashboard
        current_user: Current authenticated user
        
    Returns:
        Weight management dashboard
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        supabase = get_supabase_client()
        await verify_pet_ownership(pet_id, current_user.id, supabase)
        
        # Get weight management dashboard
        service = get_weight_service()
        dashboard = await service.get_weight_management_dashboard(pet_id, days)
        
        return dashboard
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get weight management dashboard: {str(e)}"
        )
