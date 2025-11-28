"""
Medication Reminders API Router
CRUD operations for medication reminder scheduling
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.security import HTTPAuthorizationCredentials
from typing import List, Optional

from app.database import get_db
from app.core.security.jwt_handler import get_current_user, security
from app.api.v1.dependencies import get_authenticated_supabase_client
from app.models.user import UserResponse
from supabase import Client
from app.models.medication_reminder import (
    MedicationReminder,
    MedicationReminderCreate,
    MedicationReminderUpdate,
    MedicationReminderResponse,
    MedicationReminderListResponse,
    MedicationFrequency
)
from app.services.medication_reminder_service import MedicationReminderService
from app.shared.services.pet_authorization import verify_pet_ownership

router = APIRouter(prefix="/medication-reminders", tags=["medication-reminders"])


@router.post("", response_model=MedicationReminderResponse)
async def create_medication_reminder_no_slash(
    reminder: MedicationReminderCreate,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """Create medication reminder (without trailing slash)"""
    return await create_medication_reminder_with_slash(reminder, current_user, supabase)

@router.post("/", response_model=MedicationReminderResponse)
async def create_medication_reminder_with_slash(
    reminder: MedicationReminderCreate,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Create a new medication reminder for a pet
    """
    
    # Verify pet ownership using centralized service
    await verify_pet_ownership(reminder.pet_id, current_user.id, supabase)

    # Verify health event ownership
    from app.shared.utils.async_supabase import execute_async
    health_event_response = await execute_async(
        lambda: supabase.table("health_events").select("id").eq("id", reminder.health_event_id).eq("user_id", current_user.id).execute()
    )

    if not health_event_response.data:
        from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
        raise HTTPException(
            status_code=404, 
            detail=UserFriendlyErrorMessages.get_user_friendly_message("health event not found", context="health_event", action="not_found")
        )

    # Create medication reminder using service
    db_reminder = await MedicationReminderService.create_medication_reminder(
        reminder, current_user.id, supabase
    )

    return MedicationReminderResponse(**db_reminder)


@router.get("/pet/{pet_id}", response_model=MedicationReminderListResponse)
async def get_pet_medication_reminders(
    pet_id: str,
    limit: int = Query(20, ge=1, le=100, description="Maximum results (default optimized for mobile)"),
    offset: int = Query(0, ge=0),
    active_only: bool = Query(True),
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Get medication reminders for a specific pet with optional filtering
    """
    
    # Verify pet ownership using centralized service
    await verify_pet_ownership(pet_id, current_user.id, supabase)
    
    # Get reminders using service
    reminders = await MedicationReminderService.get_medication_reminders_for_pet(
        pet_id, current_user.id, supabase, limit, offset, active_only
    )

    # Get total count
    total = await MedicationReminderService.get_medication_reminders_count_for_pet(
        pet_id, current_user.id, supabase, active_only
    )

    return MedicationReminderListResponse(
        reminders=reminders,
        total=total,
        limit=limit,
        offset=offset
    )


@router.get("/pet/{pet_id}/mobile", response_model=List[dict])
async def get_pet_medication_reminders_mobile(
    pet_id: str,
    limit: int = Query(20, ge=1, le=50, description="Maximum results (mobile optimized)"),
    offset: int = Query(0, ge=0),
    active_only: bool = Query(True),
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Mobile-optimized endpoint to get medication reminders with minimal fields.
    
    Returns only essential fields (id, pet_id, medication_name, frequency, is_active, created_at)
    for faster loading on mobile devices with limited bandwidth.
    """
    # Verify pet ownership
    await verify_pet_ownership(pet_id, current_user.id, supabase)
    
    # Get reminders with minimal fields using query builder
    from app.shared.services.query_builder_service import QueryBuilderService
    from app.shared.services.response_utils import handle_empty_response
    
    query_builder = QueryBuilderService(
        supabase,
        "medication_reminders",
        default_columns=["id", "pet_id", "medication_name", "frequency", "is_active", "created_at"]
    )
    filters = {"pet_id": pet_id, "user_id": current_user.id}
    if active_only:
        filters["is_active"] = True
    
    result = await query_builder.with_filters(filters)\
        .with_ordering("created_at", desc=True)\
        .with_limit(limit)\
        .execute()
    
    return handle_empty_response(result["data"])


@router.get("/health-event/{health_event_id}", response_model=MedicationReminderListResponse)
async def get_health_event_medication_reminders(
    health_event_id: str,
    limit: int = Query(20, ge=1, le=100, description="Maximum results (default optimized for mobile)"),
    offset: int = Query(0, ge=0),
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Get medication reminders for a specific health event
    """
    # Verify health event ownership
    from app.shared.utils.async_supabase import execute_async
    health_event_response = await execute_async(
        lambda: supabase.table("health_events").select("id").eq("id", health_event_id).eq("user_id", current_user.id).execute()
    )
    
    if not health_event_response.data:
        from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
        raise HTTPException(
            status_code=404, 
            detail=UserFriendlyErrorMessages.get_user_friendly_message("health event not found", context="health_event", action="not_found")
        )
    
    # Get reminders using service
    reminders = await MedicationReminderService.get_medication_reminders_for_health_event(
        health_event_id, current_user.id, supabase, limit, offset
    )

    # Get total count
    total = await MedicationReminderService.get_medication_reminders_count_for_health_event(
        health_event_id, current_user.id, supabase
    )

    return MedicationReminderListResponse(
        reminders=reminders,
        total=total,
        limit=limit,
        offset=offset
    )


@router.get("/{reminder_id}", response_model=MedicationReminderResponse)
async def get_medication_reminder(
    reminder_id: str,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Get a specific medication reminder by ID
    """
    reminder = await MedicationReminderService.get_medication_reminder_by_id(
        reminder_id, current_user.id, supabase
    )

    if not reminder:
        from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
        raise HTTPException(
            status_code=404, 
            detail=UserFriendlyErrorMessages.get_user_friendly_message("medication reminder not found", context="medication", action="not_found")
        )

    return reminder


@router.put("/{reminder_id}", response_model=MedicationReminderResponse)
async def update_medication_reminder(
    reminder_id: str,
    updates: MedicationReminderUpdate,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Update a medication reminder
    """
    reminder = await MedicationReminderService.update_medication_reminder(
        reminder_id, updates, current_user.id, supabase
    )

    if not reminder:
        from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
        raise HTTPException(
            status_code=404, 
            detail=UserFriendlyErrorMessages.get_user_friendly_message("medication reminder not found", context="medication", action="not_found")
        )

    return reminder


@router.delete("/{reminder_id}")
async def delete_medication_reminder(
    reminder_id: str,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Delete a medication reminder
    """
    success = await MedicationReminderService.delete_medication_reminder(
        reminder_id, current_user.id, supabase
    )
    
    if not success:
        from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
        raise HTTPException(
            status_code=404, 
            detail=UserFriendlyErrorMessages.get_user_friendly_message("medication reminder not found", context="medication", action="not_found")
        )
    
    return {"message": "Medication reminder deleted successfully"}


@router.get("/frequencies/list", response_model=List[dict])
async def get_medication_frequencies():
    """
    Get list of available medication frequencies
    """
    return [
        {
            "frequency": freq.value,
            "display_name": freq.display_name,
            "description": freq.description
        }
        for freq in MedicationFrequency
    ]


@router.post("/{reminder_id}/activate")
async def activate_medication_reminder(
    reminder_id: str,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Activate a medication reminder
    """
    success = await MedicationReminderService.activate_medication_reminder(
        reminder_id, current_user.id, supabase
    )
    
    if not success:
        from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
        raise HTTPException(
            status_code=404, 
            detail=UserFriendlyErrorMessages.get_user_friendly_message("medication reminder not found", context="medication", action="not_found")
        )
    
    return {"message": "Medication reminder activated successfully"}


@router.post("/{reminder_id}/deactivate")
async def deactivate_medication_reminder(
    reminder_id: str,
    current_user: UserResponse = Depends(get_current_user),
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Deactivate a medication reminder
    """
    success = await MedicationReminderService.deactivate_medication_reminder(
        reminder_id, current_user.id, supabase
    )
    
    if not success:
        from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
        raise HTTPException(
            status_code=404, 
            detail=UserFriendlyErrorMessages.get_user_friendly_message("medication reminder not found", context="medication", action="not_found")
        )
    
    return {"message": "Medication reminder deactivated successfully"}
