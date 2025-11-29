"""
Advanced Nutrition - Weight Management Sub-domain

Handles weight tracking, goals, and weight-related analytics.
Extracted from advanced_nutrition.py for better organization.
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query
from fastapi.security import HTTPAuthorizationCredentials
from typing import List, Optional
from datetime import datetime, date, timedelta

from app.core.database import get_supabase_client
from app.models.nutrition.advanced_nutrition import (
    PetWeightRecordCreate, PetWeightRecordResponse,
    PetWeightGoalCreate, PetWeightGoalResponse,
    WeightTrendAnalysis, WeightManagementDashboard
)
from app.models.core.user import User
from app.core.security.jwt_handler import get_current_user, security
from app.api.v1.dependencies import get_authenticated_supabase_client
from app.services import WeightTrackingService
from supabase import Client

router = APIRouter(prefix="/weight", tags=["advanced-nutrition-weight"])

# Service factory function

def get_weight_service(supabase: Client):
    """
    Get weight tracking service instance with authenticated client
    
    Args:
        supabase: Authenticated Supabase client (for RLS compliance)
        
    Returns:
        WeightTrackingService instance with authenticated client
    """
    return WeightTrackingService(supabase)


@router.post("/record", response_model=PetWeightRecordResponse)
async def record_weight(
    weight_record: PetWeightRecordCreate,
    current_user: User = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
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
        await verify_pet_ownership(weight_record.pet_id, current_user.id, supabase)
        
        # Create weight record
        service = get_weight_service(supabase)
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
    days: int = Query(365, description="Number of days to retrieve (default: 1 year, use 0 for all)"),
    current_user: User = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Get weight history for a pet
    
    Args:
        pet_id: Pet ID
        days: Number of days to retrieve (default: 365, use 0 for all records)
        current_user: Current authenticated user
        
    Returns:
        List of weight records
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id, supabase)
        
        # Get weight history
        service = get_weight_service(supabase)
        history = await service.get_weight_history(pet_id, current_user.id, days)
        
        # Return empty list if no history (200 status with empty data)
        return history if history else []
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get weight history: {str(e)}"
        )


@router.post("/goals", response_model=PetWeightGoalResponse)
async def create_weight_goal(
    weight_goal: PetWeightGoalCreate,
    current_user: User = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
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
        await verify_pet_ownership(weight_goal.pet_id, current_user.id, supabase)
        
        # Create weight goal
        service = get_weight_service(supabase)
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
    current_user: User = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
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
        await verify_pet_ownership(weight_goal.pet_id, current_user.id, supabase)
        
        # Upsert weight goal
        service = get_weight_service(supabase)
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
    current_user: User = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
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
        await verify_pet_ownership(pet_id, current_user.id, supabase)
        
        # Get active weight goal
        service = get_weight_service(supabase)
        goal = await service.get_active_weight_goal(pet_id, current_user.id)
        
        # FastAPI automatically serializes None as null in JSON for Optional response types
        # This should work correctly with Swift's JSONDecoder for optional types
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
    current_user: User = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
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
        await verify_pet_ownership(pet_id, current_user.id, supabase)
        
        # Analyze weight trend
        service = get_weight_service(supabase)
        analysis = await service.analyze_weight_trend(pet_id, current_user.id, days)
        
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
    current_user: User = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
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
        await verify_pet_ownership(pet_id, current_user.id, supabase)
        
        # Get weight management dashboard
        service = get_weight_service(supabase)
        dashboard = await service.get_weight_management_dashboard(pet_id, current_user.id)
        
        return dashboard
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get weight management dashboard: {str(e)}"
        )
