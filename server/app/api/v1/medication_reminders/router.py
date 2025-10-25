"""
Medication Reminders API Router
CRUD operations for medication reminder scheduling
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.security import HTTPAuthorizationCredentials
from typing import List, Optional

from app.database import get_db
from app.core.security.jwt_handler import get_current_user, security
from app.models.user import UserResponse
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
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """Create medication reminder (without trailing slash)"""
    return await create_medication_reminder_with_slash(reminder, current_user, credentials)

@router.post("/", response_model=MedicationReminderResponse)
async def create_medication_reminder_with_slash(
    reminder: MedicationReminderCreate,
    current_user: UserResponse = Depends(get_current_user),
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """
    Create a new medication reminder for a pet
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
    await verify_pet_ownership(reminder.pet_id, current_user.id, supabase)

    # Verify health event ownership
    health_event_response = supabase.table("health_events").select("id").eq("id", reminder.health_event_id).eq("user_id", current_user.id).execute()

    if not health_event_response.data:
        raise HTTPException(status_code=404, detail="Health event not found")

    # Create medication reminder using service
    db_reminder = await MedicationReminderService.create_medication_reminder(
        reminder, current_user.id, supabase
    )

    return MedicationReminderResponse(**db_reminder)


@router.get("/pet/{pet_id}", response_model=MedicationReminderListResponse)
async def get_pet_medication_reminders(
    pet_id: str,
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    active_only: bool = Query(True),
    current_user: UserResponse = Depends(get_current_user),
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """
    Get medication reminders for a specific pet with optional filtering
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


@router.get("/health-event/{health_event_id}", response_model=MedicationReminderListResponse)
async def get_health_event_medication_reminders(
    health_event_id: str,
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    supabase = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get medication reminders for a specific health event
    """
    # Verify health event ownership
    health_event_response = supabase.table("health_events").select("id").eq("id", health_event_id).eq("user_id", current_user.id).execute()
    
    if not health_event_response.data:
        raise HTTPException(status_code=404, detail="Health event not found")
    
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
    supabase = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Get a specific medication reminder by ID
    """
    reminder = await MedicationReminderService.get_medication_reminder_by_id(
        reminder_id, current_user.id, supabase
    )

    if not reminder:
        raise HTTPException(status_code=404, detail="Medication reminder not found")

    return reminder


@router.put("/{reminder_id}", response_model=MedicationReminderResponse)
async def update_medication_reminder(
    reminder_id: str,
    updates: MedicationReminderUpdate,
    supabase = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Update a medication reminder
    """
    reminder = await MedicationReminderService.update_medication_reminder(
        reminder_id, updates, current_user.id, supabase
    )

    if not reminder:
        raise HTTPException(status_code=404, detail="Medication reminder not found")

    return reminder


@router.delete("/{reminder_id}")
async def delete_medication_reminder(
    reminder_id: str,
    supabase = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Delete a medication reminder
    """
    success = await MedicationReminderService.delete_medication_reminder(
        reminder_id, current_user.id, supabase
    )
    
    if not success:
        raise HTTPException(status_code=404, detail="Medication reminder not found")
    
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
    supabase = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Activate a medication reminder
    """
    success = await MedicationReminderService.activate_medication_reminder(
        reminder_id, current_user.id, supabase
    )
    
    if not success:
        raise HTTPException(status_code=404, detail="Medication reminder not found")
    
    return {"message": "Medication reminder activated successfully"}


@router.post("/{reminder_id}/deactivate")
async def deactivate_medication_reminder(
    reminder_id: str,
    supabase = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    Deactivate a medication reminder
    """
    success = await MedicationReminderService.deactivate_medication_reminder(
        reminder_id, current_user.id, supabase
    )
    
    if not success:
        raise HTTPException(status_code=404, detail="Medication reminder not found")
    
    return {"message": "Medication reminder deactivated successfully"}
