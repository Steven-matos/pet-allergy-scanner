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
    # CRITICAL: Print immediately to verify route is being hit
    import sys
    import logging
    # Force immediate flush to ensure logs appear
    print("=" * 80, file=sys.stderr, flush=True)
    print("🚨 HEALTH EVENTS ENDPOINT HIT!", file=sys.stderr, flush=True)
    print(f"   pet_id: {pet_id}", file=sys.stderr, flush=True)
    print(f"   user_id: {current_user.id}", file=sys.stderr, flush=True)
    print(f"   limit: {limit}, offset: {offset}, category: {category}", file=sys.stderr, flush=True)
    print("=" * 80, file=sys.stderr, flush=True)
    
    # Also log to standard logger with immediate flush
    logging.getLogger().handlers[0].flush() if logging.getLogger().handlers else None
    
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
    # Map database fields to API model fields
    health_event_responses = []
    for event in events:
        try:
            # Map 'description' to 'notes' if present (database has description, API expects notes)
            event_dict = dict(event)
            if 'description' in event_dict and 'notes' not in event_dict:
                event_dict['notes'] = event_dict.pop('description', None)
            elif 'description' in event_dict and event_dict.get('notes') is None:
                # If notes is None but description exists, use description
                event_dict['notes'] = event_dict.get('description')
            
            # Remove any extra fields that aren't in the model
            response = HealthEventResponse(**event_dict)
            health_event_responses.append(response)
        except Exception as e:
            logger.error(f"❌ [get_pet_health_events] Error converting event {event.get('id', 'unknown')}: {e}")
            logger.error(f"   Event data: {event}")
            # Skip invalid events but log them
            continue
    
    logger.info(f"✅ [get_pet_health_events] Converted {len(health_event_responses)} events to response format")
    
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


@router.get("/pet/{pet_id}/debug", response_model=dict)
async def debug_health_events(
    pet_id: str,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Debug endpoint to test health events query - bypasses RLS to diagnose issues
    WARNING: Only use for debugging, remove in production
    """
    from app.utils.logging_config import get_logger
    from app.shared.services.supabase_auth_service import SupabaseAuthService
    logger = get_logger(__name__)
    
    logger.info(f"🔧 [DEBUG] Testing health events for pet: {pet_id}, user: {current_user.id}")
    print(f"🔧 [DEBUG] Testing health events for pet: {pet_id}, user: {current_user.id}")
    
    # Use service role to bypass RLS
    service_client = SupabaseAuthService.create_service_role_client()
    
    # Check pet ownership
    pet_check = service_client.table("pets").select("id, user_id, name").eq("id", pet_id).execute()
    pet_data = pet_check.data[0] if pet_check.data else None
    
    # Check events with service role (bypasses RLS)
    events_check = service_client.table("health_events").select("*").eq("pet_id", pet_id).execute()
    all_events = events_check.data if events_check.data else []
    
    # Check events with authenticated client (with RLS)
    rls_events_check = supabase.table("health_events").select("*").eq("pet_id", pet_id).execute()
    rls_events = rls_events_check.data if rls_events_check.data else []
    
    # Check events filtered by user_id with RLS
    user_filtered_check = supabase.table("health_events").select("*").eq("pet_id", pet_id).eq("user_id", current_user.id).execute()
    user_filtered_events = user_filtered_check.data if user_filtered_check.data else []
    
    result = {
        "pet_id": pet_id,
        "user_id": current_user.id,
        "pet": pet_data,
        "events_bypassing_rls": len(all_events),
        "events_with_rls": len(rls_events),
        "events_with_user_filter": len(user_filtered_events),
        "all_events_sample": all_events[:2] if all_events else [],
        "rls_events_sample": rls_events[:2] if rls_events else [],
        "user_filtered_sample": user_filtered_events[:2] if user_filtered_events else []
    }
    
    logger.info(f"🔧 [DEBUG] Result: {result}")
    print(f"🔧 [DEBUG] Result: {result}")
    
    return result
