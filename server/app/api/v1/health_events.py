"""
Health Events API Router
CRUD operations for pet health event tracking
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from typing import List, Optional
from datetime import datetime
from sqlalchemy.orm import Session
from sqlalchemy import desc, and_

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.health_event import (
    HealthEvent,
    HealthEventCreate,
    HealthEventUpdate,
    HealthEventResponse,
    HealthEventListResponse,
    HealthEventCategory
)
from app.models.pet import Pet
from app.services.health_event_service import HealthEventService

router = APIRouter(prefix="/health-events", tags=["health-events"])


@router.post("/", response_model=HealthEventResponse)
async def create_health_event(
    event: HealthEventCreate,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Create a new health event for a pet
    """
    # Verify pet ownership
    pet = db.query(Pet).filter(
        and_(
            Pet.id == event.pet_id,
            Pet.user_id == current_user["id"]
        )
    ).first()
    
    if not pet:
        raise HTTPException(status_code=404, detail="Pet not found")
    
    # Create health event using service
    db_event = await HealthEventService.create_health_event(
        event, current_user["id"], db
    )
    
    return HealthEventResponse.from_orm(db_event)


@router.get("/pet/{pet_id}", response_model=HealthEventListResponse)
async def get_pet_health_events(
    pet_id: str,
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    category: Optional[str] = Query(None),
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get health events for a specific pet with optional filtering
    """
    # Verify pet ownership
    pet = db.query(Pet).filter(
        and_(
            Pet.id == pet_id,
            Pet.user_id == current_user["id"]
        )
    ).first()
    
    if not pet:
        raise HTTPException(status_code=404, detail="Pet not found")
    
    # Get events using service
    if category:
        try:
            category_enum = HealthEventCategory(category)
            events = await HealthEventService.get_health_events_by_category(
                pet_id, category_enum.value, current_user["id"], db, limit, offset
            )
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid category")
    else:
        events = await HealthEventService.get_health_events_for_pet(
            pet_id, current_user["id"], db, limit, offset
        )
    
    # Get total count
    total = await HealthEventService.get_health_events_count_for_pet(
        pet_id, current_user["id"], db
    )
    
    return HealthEventListResponse(
        events=[HealthEventResponse.from_orm(event) for event in events],
        total=total,
        limit=limit,
        offset=offset
    )


@router.get("/{event_id}", response_model=HealthEventResponse)
async def get_health_event(
    event_id: str,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get a specific health event by ID
    """
    event = await HealthEventService.get_health_event_by_id(
        event_id, current_user["id"], db
    )
    
    if not event:
        raise HTTPException(status_code=404, detail="Health event not found")
    
    return HealthEventResponse.from_orm(event)


@router.put("/{event_id}", response_model=HealthEventResponse)
async def update_health_event(
    event_id: str,
    updates: HealthEventUpdate,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Update a health event
    """
    event = await HealthEventService.update_health_event(
        event_id, updates, current_user["id"], db
    )
    
    if not event:
        raise HTTPException(status_code=404, detail="Health event not found")
    
    return HealthEventResponse.from_orm(event)


@router.delete("/{event_id}")
async def delete_health_event(
    event_id: str,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Delete a health event
    """
    success = await HealthEventService.delete_health_event(
        event_id, current_user["id"], db
    )
    
    if not success:
        raise HTTPException(status_code=404, detail="Health event not found")
    
    return {"message": "Health event deleted successfully"}


@router.get("/categories/list", response_model=List[str])
async def get_health_event_categories():
    """
    Get list of available health event categories
    """
    return [category.value for category in HealthEventCategory]


@router.get("/types/list", response_model=List[dict])
async def get_health_event_types():
    """
    Get list of available health event types with their categories
    """
    from app.models.health_event import HealthEventType
    
    return [
        {
            "type": event_type.value,
            "display_name": event_type.value.replace("_", " ").title(),
            "category": event_type.category.value if hasattr(event_type, 'category') else "physical"
        }
        for event_type in HealthEventType
    ]
