"""
Nutrition Feeding Sub-domain Router

Handles feeding records and daily nutrition summaries.
Extracted from app.routers.nutrition for better organization.
"""

from fastapi import APIRouter, Depends, HTTPException
from typing import List, Optional
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.nutrition import (
    FeedingRecordCreate,
    FeedingRecordResponse,
    DailyNutritionSummaryResponse
)
from app.models.user import UserResponse
from app.core.security.jwt_handler import get_current_user
# Removed unused imports: create_error_response, APIError

router = APIRouter(prefix="/feeding", tags=["nutrition-feeding"])


@router.post("/", response_model=FeedingRecordResponse)
async def record_feeding(
    feeding_record: FeedingRecordCreate,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Record a feeding event for a pet
    
    Args:
        feeding_record: Feeding record data
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        Created feeding record
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(feeding_record.pet_id, current_user.id)
        
        # Create feeding record
        record_data = feeding_record.dict()
        record_data['user_id'] = current_user.id
        
        db_record = FeedingRecordCreate(**record_data)
        db.add(db_record)
        db.commit()
        db.refresh(db_record)
        
        return FeedingRecordResponse.from_orm(db_record)
        
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Failed to record feeding: {str(e)}"
        )


@router.get("/{pet_id}", response_model=List[FeedingRecordResponse])
async def get_feeding_records(
    pet_id: str,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get feeding records for a pet
    
    Args:
        pet_id: Pet ID
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        List of feeding records for the pet
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id)
        
        # Get feeding records
        records = db.query(FeedingRecordCreate).filter(
            FeedingRecordCreate.pet_id == pet_id,
            FeedingRecordCreate.user_id == current_user.id
        ).order_by(FeedingRecordCreate.created_at.desc()).all()
        
        return [FeedingRecordResponse.from_orm(record) for record in records]
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get feeding records: {str(e)}"
        )


@router.get("/summaries/{pet_id}", response_model=List[DailyNutritionSummaryResponse])
async def get_daily_summaries(
    pet_id: str,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get daily nutrition summaries for a pet
    
    Args:
        pet_id: Pet ID
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        List of daily nutrition summaries
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id)
        
        # Get daily summaries (this would contain the actual summary logic)
        summaries = []  # Placeholder for actual summary generation
        
        return summaries
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get daily summaries: {str(e)}"
        )


@router.get("/daily-summary/{pet_id}", response_model=Optional[DailyNutritionSummaryResponse])
async def get_daily_summary(
    pet_id: str,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get today's nutrition summary for a pet
    
    Args:
        pet_id: Pet ID
        db: Database session
        current_user: Current authenticated user
        
    Returns:
        Today's nutrition summary
        
    Raises:
        HTTPException: If pet not found or user not authorized
    """
    try:
        # Verify pet ownership
        from app.shared.services.pet_authorization import verify_pet_ownership
        await verify_pet_ownership(pet_id, current_user.id)
        
        # Get today's summary (this would contain the actual summary logic)
        summary = None  # Placeholder for actual summary generation
        
        return summary
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get daily summary: {str(e)}"
        )
