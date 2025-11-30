"""
Health Events API Router
CRUD operations for pet health event tracking
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.security import HTTPAuthorizationCredentials
from typing import List, Optional

from app.core.database import get_db
from app.core.security.jwt_handler import get_current_user, security
from app.api.v1.dependencies import get_authenticated_supabase_client
from app.models.core.user import UserResponse
from supabase import Client
from app.models.health.health_event import (
    HealthEvent,
    HealthEventCreate,
    HealthEventUpdate,
    HealthEventResponse,
    HealthEventListResponse,
    HealthEventCategory
)
from app.services import HealthEventService
from app.shared.services.pet_authorization import verify_pet_ownership
from app.shared.services.response_utils import handle_empty_response

router = APIRouter(prefix="/health-events", tags=["health-events"])


@router.post("", response_model=HealthEventResponse)
async def create_health_event_no_slash(
    event: HealthEventCreate,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """Create health event (without trailing slash)"""
    return await create_health_event_with_slash(event, current_user, supabase)

@router.post("/", response_model=HealthEventResponse)
async def create_health_event_with_slash(
    event: HealthEventCreate,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Create a new health event for a pet
    """
    
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
    limit: int = Query(20, ge=1, le=100, description="Maximum results (default optimized for mobile)"),
    offset: int = Query(0, ge=0),
    category: Optional[str] = Query(None),
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Get health events for a specific pet with optional filtering
    """
    from app.utils.logging_config import get_logger
    logger = get_logger(__name__)
    
    # Use both logger and print to ensure visibility
    logger.info(f"🔍 [get_pet_health_events] Request received")
    logger.info(f"   pet_id: {pet_id}")
    logger.info(f"   current_user.id: {current_user.id}")
    logger.info(f"   limit: {limit}, offset: {offset}, category: {category}")
    print(f"🔍 [HEALTH_EVENTS_ROUTER] Request received - pet_id: {pet_id}, user_id: {current_user.id}")
    
    try:
        # Verify pet ownership using centralized service
        await verify_pet_ownership(pet_id, current_user.id, supabase)
        logger.info(f"✅ [get_pet_health_events] Pet ownership verified")
    except Exception as e:
        logger.error(f"❌ [get_pet_health_events] Pet ownership verification failed: {e}")
        raise
    
    # Get events using service
    try:
        if category:
            try:
                category_enum = HealthEventCategory(category)
                events = await HealthEventService.get_health_events_by_category(
                    pet_id, category_enum.value, current_user.id, supabase, limit, offset
                )
            except ValueError:
                from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
                raise HTTPException(
                    status_code=400, 
                    detail=UserFriendlyErrorMessages.get_user_friendly_message("invalid format")
                )
        else:
            logger.info(f"📞 [get_pet_health_events] Calling service.get_health_events_for_pet()")
            events = await HealthEventService.get_health_events_for_pet(
                pet_id, current_user.id, supabase, limit, offset
            )
            logger.info(f"📥 [get_pet_health_events] Service returned {len(events)} events")

        # Get total count
        logger.info(f"📞 [get_pet_health_events] Calling service.get_health_events_count_for_pet()")
        total = await HealthEventService.get_health_events_count_for_pet(
            pet_id, current_user.id, supabase
        )
        logger.info(f"📥 [get_pet_health_events] Service returned total: {total}")
        
        logger.info(f"📊 [get_pet_health_events] Returning {len(events)} events, total: {total}")
        print(f"📊 [HEALTH_EVENTS_ROUTER] Returning {len(events)} events, total: {total}")
    except Exception as e:
        logger.error(f"❌ [get_pet_health_events] Error getting events: {e}", exc_info=True)
        print(f"❌ [HEALTH_EVENTS_ROUTER] Error: {e}")
        raise

    # Convert raw database dictionaries to HealthEventResponse objects
    health_event_responses = [HealthEventResponse(**event) for event in events]
    
    return HealthEventListResponse(
        events=health_event_responses,
        total=total,
        limit=limit,
        offset=offset
    )


@router.get("/pet/{pet_id}/mobile", response_model=List[dict])
async def get_pet_health_events_mobile(
    pet_id: str,
    limit: int = Query(20, ge=1, le=50, description="Maximum results (mobile optimized)"),
    offset: int = Query(0, ge=0),
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Mobile-optimized endpoint to get health events with minimal fields.
    
    Returns only essential fields (id, pet_id, event_category, event_date, severity, created_at)
    for faster loading on mobile devices with limited bandwidth.
    """
    # Verify pet ownership
    await verify_pet_ownership(pet_id, current_user.id, supabase)
    
    # Get events using service with minimal fields
    from app.shared.services.query_builder_service import QueryBuilderService
    
    query_builder = QueryBuilderService(
        supabase,
        "health_events",
        default_columns=["id", "pet_id", "event_category", "event_date", "severity", "created_at"]
    )
    result = await query_builder.with_filters({"pet_id": pet_id, "user_id": current_user.id})\
        .with_ordering("event_date", desc=True)\
        .with_limit(limit)\
        .execute()
    
    return handle_empty_response(result["data"])


@router.get("/{event_id}", response_model=HealthEventResponse)
async def get_health_event(
    event_id: str,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Get a specific health event by ID
    """
    
    event = await HealthEventService.get_health_event_by_id(
        event_id, current_user.id, supabase
    )

    if not event:
        from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
        raise HTTPException(
            status_code=404, 
            detail=UserFriendlyErrorMessages.get_user_friendly_message("health event not found", context="health_event", action="not_found")
        )

    return HealthEventResponse(**event)


@router.put("/{event_id}", response_model=HealthEventResponse)
async def update_health_event(
    event_id: str,
    updates: HealthEventUpdate,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Update a health event
    """
    
    event = await HealthEventService.update_health_event(
        event_id, updates, current_user.id, supabase
    )

    if not event:
        from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
        raise HTTPException(
            status_code=404, 
            detail=UserFriendlyErrorMessages.get_user_friendly_message("health event not found", context="health_event", action="not_found")
        )

    return HealthEventResponse(**event)


@router.delete("/{event_id}")
async def delete_health_event(
    event_id: str,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Delete a health event
    """
    
    success = await HealthEventService.delete_health_event(
        event_id, current_user.id, supabase
    )
    
    if not success:
        from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
        raise HTTPException(
            status_code=404, 
            detail=UserFriendlyErrorMessages.get_user_friendly_message("health event not found", context="health_event", action="not_found")
        )
    
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
    from app.models.health.health_event import HealthEventType
    
    return [
        {
            "type": event_type.value,
            "display_name": event_type.value.replace("_", " ").title(),
            "category": event_type.category.value if hasattr(event_type, 'category') else "physical"
        }
        for event_type in HealthEventType
    ]
