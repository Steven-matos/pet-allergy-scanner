"""
Nutrition Feeding Sub-domain Router

Handles feeding records and daily nutrition summaries.
Extracted from app.routers.nutrition for better organization.
"""

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from typing import List, Optional
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

# Import centralized services
from app.shared.services.database_operation_service import DatabaseOperationService
from app.shared.services.response_model_service import ResponseModelService
from app.shared.services.response_utils import handle_empty_response
from app.shared.services.query_builder_service import QueryBuilderService
from app.shared.services.data_transformation_service import DataTransformationService
from app.shared.services.id_generation_service import IDGenerationService
from app.shared.decorators.error_handler import handle_errors

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
@handle_errors("record_feeding")
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
    # Verify pet ownership
    from app.shared.services.pet_authorization import verify_pet_ownership
    await verify_pet_ownership(feeding_record.pet_id, current_user.id, supabase)
    
    # Create feeding record using data transformation service
    # Note: feeding_records table only has pet_id, not user_id
    # Authorization is handled via RLS policies checking pet ownership
    record_data = DataTransformationService.model_to_dict(feeding_record)
    record_data['id'] = IDGenerationService.generate_uuid()
    
    # Insert into database using centralized service
    db_service = DatabaseOperationService(supabase)
    created_record = db_service.insert_with_timestamps("feeding_records", record_data)
    
    # Convert to response model
    return ResponseModelService.convert_to_model(created_record, FeedingRecordResponse)


@router.get("/{pet_id}", response_model=List[FeedingRecordResponse])
@handle_errors("get_feeding_records")
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
    # Verify pet ownership
    from app.shared.services.pet_authorization import verify_pet_ownership
    await verify_pet_ownership(pet_id, current_user.id, supabase)
    
    # Get feeding records using query builder
    # Note: feeding_records table only has pet_id, not user_id
    # Authorization is handled via RLS policies checking pet ownership
    query_builder = QueryBuilderService(supabase, "feeding_records")
    result = query_builder.with_filters({"pet_id": pet_id})\
        .with_ordering("created_at", desc=True)\
        .execute()
    
    # Handle empty response
    records_data = handle_empty_response(result["data"])
    
    # Convert to response models
    return ResponseModelService.convert_list_to_models(records_data, FeedingRecordResponse)


@router.get("/summaries/{pet_id}", response_model=List[DailyNutritionSummaryResponse])
@handle_errors("get_daily_summaries")
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
    # Verify pet ownership
    from app.shared.services.pet_authorization import verify_pet_ownership
    await verify_pet_ownership(pet_id, current_user.id, supabase)
    
    # Get daily summaries (this would contain the actual summary logic)
    summaries = []  # Placeholder for actual summary generation
    
    return summaries


@router.get("/daily-summary/{pet_id}", response_model=Optional[DailyNutritionSummaryResponse])
@handle_errors("get_daily_summary")
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
    # Verify pet ownership
    from app.shared.services.pet_authorization import verify_pet_ownership
    await verify_pet_ownership(pet_id, current_user.id, supabase)
    
    # Get today's summary (this would contain the actual summary logic)
    summary = None  # Placeholder for actual summary generation
    
    return summary
