"""
Health Events API Router
CRUD operations for pet health event tracking
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.security import HTTPAuthorizationCredentials
from typing import List, Optional

from app.database import get_db
from app.core.security.jwt_handler import get_current_user, security
from app.models.user import UserResponse
from app.models.health_event import (
    HealthEvent,
    HealthEventCreate,
    HealthEventUpdate,
    HealthEventResponse,
    HealthEventListResponse,
    HealthEventCategory
)
from app.services.health_event_service import HealthEventService
from app.shared.services.pet_authorization import verify_pet_ownership

router = APIRouter(prefix="/health-events", tags=["health-events"])


@router.post("", response_model=HealthEventResponse)
async def create_health_event_no_slash(
    event: HealthEventCreate,
    current_user: UserResponse = Depends(get_current_user),
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """Create health event (without trailing slash)"""
    return await create_health_event_with_slash(event, current_user, credentials)

@router.post("/", response_model=HealthEventResponse)
async def create_health_event_with_slash(
    event: HealthEventCreate,
    current_user: UserResponse = Depends(get_current_user),
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """
    Create a new health event for a pet
    """
    # Create authenticated Supabase client with user's JWT token
    from app.core.config import settings
    from supabase import create_client
    
    supabase = create_client(
        settings.supabase_url,
        settings.supabase_key
    )
    
    # Set the session with the user's JWT token
    supabase.auth.set_session(credentials.credentials, "")
    
    # Verify pet ownership using centralized service
    await verify_pet_ownership(event.pet_id, current_user.id, supabase)

    # Create health event using service
    db_event = await HealthEventService.create_health_event(
        event, current_user.id, supabase
    )

    return HealthEventResponse(**db_event)


@router.get("/pet/{pet_id}", response_model=HealthEventListResponse)
async def get_pet_health_events(
    pet_id: str,
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    category: Optional[str] = Query(None),
    current_user: UserResponse = Depends(get_current_user),
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """
    Get health events for a specific pet with optional filtering
    """
    # Create authenticated Supabase client with user's JWT token
    from app.core.config import settings
    from supabase import create_client
    
    supabase = create_client(
        settings.supabase_url,
        settings.supabase_key
    )
    
    # Set the session with the user's JWT token
    supabase.auth.set_session(credentials.credentials, "")
    
    # Verify pet ownership using centralized service
    await verify_pet_ownership(pet_id, current_user.id, supabase)
    
    # Get events using service
    if category:
        try:
            category_enum = HealthEventCategory(category)
            events = await HealthEventService.get_health_events_by_category(
                pet_id, category_enum.value, current_user.id, supabase, limit, offset
            )
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid category")
    else:
        events = await HealthEventService.get_health_events_for_pet(
            pet_id, current_user.id, supabase, limit, offset
        )

    # Get total count
    total = await HealthEventService.get_health_events_count_for_pet(
        pet_id, current_user.id, supabase
    )

    # Convert raw database dictionaries to HealthEventResponse objects
    health_event_responses = [HealthEventResponse(**event) for event in events]
    
    return HealthEventListResponse(
        events=health_event_responses,
        total=total,
        limit=limit,
        offset=offset
    )


@router.get("/{event_id}", response_model=HealthEventResponse)
async def get_health_event(
    event_id: str,
    current_user: UserResponse = Depends(get_current_user),
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """
    Get a specific health event by ID
    """
    # Create authenticated Supabase client
    from app.core.config import settings
    from supabase import create_client
    
    supabase = create_client(
        settings.supabase_url,
        settings.supabase_key
    )
    supabase.auth.set_session(credentials.credentials, "")
    
    event = await HealthEventService.get_health_event_by_id(
        event_id, current_user.id, supabase
    )

    if not event:
        raise HTTPException(status_code=404, detail="Health event not found")

    return HealthEventResponse(**event)


@router.put("/{event_id}", response_model=HealthEventResponse)
async def update_health_event(
    event_id: str,
    updates: HealthEventUpdate,
    current_user: UserResponse = Depends(get_current_user),
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """
    Update a health event
    """
    # Create authenticated Supabase client
    from app.core.config import settings
    from supabase import create_client
    
    supabase = create_client(
        settings.supabase_url,
        settings.supabase_key
    )
    supabase.auth.set_session(credentials.credentials, "")
    
    event = await HealthEventService.update_health_event(
        event_id, updates, current_user.id, supabase
    )

    if not event:
        raise HTTPException(status_code=404, detail="Health event not found")

    return HealthEventResponse(**event)


@router.delete("/{event_id}")
async def delete_health_event(
    event_id: str,
    current_user: UserResponse = Depends(get_current_user),
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """
    Delete a health event
    """
    # Create authenticated Supabase client
    from app.core.config import settings
    from supabase import create_client
    
    supabase = create_client(
        settings.supabase_url,
        settings.supabase_key
    )
    supabase.auth.set_session(credentials.credentials, "")
    
    success = await HealthEventService.delete_health_event(
        event_id, current_user.id, supabase
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
