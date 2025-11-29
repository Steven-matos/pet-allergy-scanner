"""
Advanced Nutrition - Weight Management Sub-domain

Handles weight tracking, goals, and weight-related analytics.
Extracted from advanced_nutrition.py for better organization.
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query, Response
from fastapi.security import HTTPAuthorizationCredentials
from fastapi.responses import JSONResponse
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
    response: Response,
    days: int = Query(365, description="Number of days to retrieve (default: 1 year, use 0 for all)"),
    current_user: User = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Get weight history for a pet
    
    Args:
        pet_id: Pet ID
        response: Response object to set headers
        days: Number of days to retrieve (default: 365, use 0 for all records)
        current_user: Current authenticated user
        
    Returns:
        List of weight records
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    from app.utils.logging_config import get_logger
    logger = get_logger(__name__)
    
    # CRITICAL: Disable caching for dynamic weight data
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
    
    logger.info(f"[ROUTER] GET /history/{pet_id} - Starting request")
    logger.info(f"[ROUTER] User: {current_user.id}, Days: {days}")
    
    try:
        
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id, supabase)
        
        logger.info(f"[ROUTER] Pet ownership verified")
        
        # Get weight history
        service = get_weight_service(supabase)
        logger.info(f"[ROUTER] Calling service.get_weight_history()")
        history = await service.get_weight_history(pet_id, current_user.id, days)
        
        logger.info(f"[ROUTER] Service returned {len(history)} records")
        
        # Return empty list if no history (200 status with empty data)
        result = history if history else []
        logger.info(f"[ROUTER] Returning {len(result)} records to client")
        return result
        
    except Exception as e:
        logger.error(f"[ROUTER] Error getting weight history: {e}", exc_info=True)
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
    response: Response,
    current_user: User = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Get active weight goal for a pet
    
    Args:
        pet_id: Pet ID
        response: Response object to set headers
        current_user: Current authenticated user
        
    Returns:
        Active weight goal or None
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    from app.utils.logging_config import get_logger
    logger = get_logger(__name__)
    
    # CRITICAL: Disable caching for dynamic goal data
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
    
    logger.info(f"[ROUTER] GET /goals/{pet_id}/active - Starting request")
    logger.info(f"[ROUTER] User: {current_user.id}")
    
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id, supabase)
        
        logger.info(f"[ROUTER] Pet ownership verified")
        
        # Get active weight goal
        service = get_weight_service(supabase)
        logger.info(f"[ROUTER] Calling service.get_active_weight_goal()")
        goal = await service.get_active_weight_goal(pet_id, current_user.id)
        
        logger.info(f"[ROUTER] Service returned goal: {goal is not None}")
        if goal:
            logger.info(f"[ROUTER] Goal ID: {goal.id}, Target: {goal.target_weight_kg}kg")
        
        # FastAPI automatically serializes None as null in JSON for Optional response types
        # This should work correctly with Swift's JSONDecoder for optional types
        logger.info(f"[ROUTER] Returning goal to client: {goal}")
        return goal
        
    except Exception as e:
        logger.error(f"[ROUTER] Error getting active weight goal: {e}", exc_info=True)
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
        


@router.delete("/record/{record_id}")
async def delete_weight_record(
    record_id: str,
    current_user: User = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Delete a weight record and update pet's weight to previous record
    
    This is primarily used for the "undo" functionality after recording a weight.
    When a record is deleted, the pet's weight is automatically updated to the
    previous recorded weight (or cleared if no previous weights exist).
    
    Args:
        record_id: Weight record ID to delete
        current_user: Current authenticated user
        
    Returns:
        Success message with updated pet weight info
        
    Raises:
        HTTPException: If record not found, user not authorized, or deletion fails
    """
    from app.utils.logging_config import get_logger
    logger = get_logger(__name__)
    
    logger.info(f"[ROUTER] DELETE /record/{record_id} - Starting request")
    logger.info(f"[ROUTER] User: {current_user.id}")
    
    try:
        # Get the weight record to verify ownership
        record_response = supabase.table("pet_weight_records").select("*").eq("id", record_id).execute()
        
        if not record_response.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Weight record not found"
            )
        
        record = record_response.data[0]
        pet_id = record["pet_id"]
        
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id, supabase)
        
        logger.info(f"[ROUTER] Pet ownership verified for pet: {pet_id}")
        
        # Delete the record using the service
        service = get_weight_service(supabase)
        result = await service.delete_weight_record(record_id, pet_id, current_user.id)
        
        logger.info(f"[ROUTER] Weight record deleted successfully")
        logger.info(f"[ROUTER] Result: {result}")
        
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content=result
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[ROUTER] Error deleting weight record: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete weight record: {str(e)}"
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
