"""
Nutrition Feeding Sub-domain Router

Handles feeding records and daily nutrition summaries.
Extracted from app.routers.nutrition for better organization.
"""

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from typing import List, Optional
import uuid
from datetime import datetime

from app.database import get_db
from app.models.nutrition import (
    FeedingRecordCreate,
    FeedingRecordResponse,
    DailyNutritionSummaryResponse
)
from app.models.user import UserResponse
from app.core.security.jwt_handler import get_current_user, security
from app.api.v1.dependencies import get_authenticated_supabase_client
from app.utils.logging_config import get_logger
from supabase import Client

logger = get_logger(__name__)
router = APIRouter(prefix="/feeding", tags=["nutrition-feeding"])


@router.post("", response_model=FeedingRecordResponse)
async def record_feeding_no_slash(
    feeding_record: FeedingRecordCreate,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """Record feeding (without trailing slash)"""
    return await record_feeding_with_slash(feeding_record, current_user, supabase)

@router.post("/", response_model=FeedingRecordResponse)
async def record_feeding_with_slash(
    feeding_record: FeedingRecordCreate,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Record a feeding event for a pet
    
    Args:
        feeding_record: Feeding record data
        supabase: Authenticated Supabase client
        current_user: Current authenticated user
        
    Returns:
        Created feeding record
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(feeding_record.pet_id, current_user.id, supabase)
        
        # Create feeding record
        # Note: feeding_records table only has pet_id, not user_id
        # Authorization is handled via RLS policies checking pet ownership
        record_data = feeding_record.dict()
        record_data['id'] = str(uuid.uuid4())
        
        # Insert into database
        response = supabase.table("feeding_records").insert(record_data).execute()
        
        if not response.data:
            raise HTTPException(status_code=500, detail="Failed to create feeding record")
        
        created_record = response.data[0]
        return FeedingRecordResponse(**created_record)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to record feeding: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to record feeding: {str(e)}"
        )


@router.get("/{pet_id}", response_model=List[FeedingRecordResponse])
async def get_feeding_records(
    pet_id: str,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Get feeding records for a pet
    
    Args:
        pet_id: Pet ID
        supabase: Authenticated Supabase client
        current_user: Current authenticated user
        
    Returns:
        List of feeding records for the pet
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id, supabase)
        
        # Get feeding records
        # Note: feeding_records table only has pet_id, not user_id
        # Authorization is handled via RLS policies checking pet ownership
        response = supabase.table("feeding_records").select("*").eq("pet_id", pet_id).order("created_at", desc=True).execute()
        
        if not response.data:
            return []
        
        return [FeedingRecordResponse(**record) for record in response.data]
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get feeding records: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get feeding records: {str(e)}"
        )


@router.get("/summaries/{pet_id}", response_model=List[DailyNutritionSummaryResponse])
async def get_daily_summaries(
    pet_id: str,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Get daily nutrition summaries for a pet
    
    Args:
        pet_id: Pet ID
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
        logger.error(f"Failed to get daily summaries: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get daily summaries: {str(e)}"
        )


@router.get("/daily-summary/{pet_id}", response_model=Optional[DailyNutritionSummaryResponse])
async def get_daily_summary(
    pet_id: str,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Get today's nutrition summary for a pet
    
    Args:
        pet_id: Pet ID
        supabase: Authenticated Supabase client
        current_user: Current authenticated user
        
    Returns:
        Today's nutrition summary
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id, supabase)
        
        # Get today's summary (this would contain the actual summary logic)
        summary = None  # Placeholder for actual summary generation
        
        return summary
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get daily summary: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get daily summary: {str(e)}"
        )
