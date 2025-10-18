"""
Medication Reminder Service
Business logic for medication reminder management
"""

from datetime import datetime
from typing import List, Optional, Dict, Any
import json

from app.models.medication_reminder import (
    MedicationReminder,
    MedicationReminderCreate,
    MedicationReminderUpdate,
    MedicationReminderResponse
)


class MedicationReminderService:
    """Service for managing medication reminders"""
    
    @staticmethod
    async def create_medication_reminder(
        reminder_data: MedicationReminderCreate,
        user_id: str,
        supabase
    ) -> Dict[str, Any]:
        """
        Create a new medication reminder
        """
        # Prepare reminder data for database
        db_reminder = {
            "health_event_id": reminder_data.health_event_id,
            "pet_id": reminder_data.pet_id,
            "user_id": user_id,
            "medication_name": reminder_data.medication_name,
            "dosage": reminder_data.dosage,
            "frequency": reminder_data.frequency.value,
            "reminder_times": json.dumps([rt.model_dump() for rt in reminder_data.reminder_times]),
            "start_date": reminder_data.start_date.isoformat(),
            "end_date": reminder_data.end_date.isoformat() if reminder_data.end_date else None,
            "is_active": reminder_data.is_active
        }
        
        # Insert into database
        response = supabase.table("medication_reminders").insert(db_reminder).execute()
        
        if not response.data:
            raise Exception("Failed to create medication reminder")
        
        return response.data[0]
    
    @staticmethod
    async def get_medication_reminders_for_pet(
        pet_id: str,
        user_id: str,
        supabase,
        limit: int = 50,
        offset: int = 0,
        active_only: bool = True
    ) -> List[Dict[str, Any]]:
        """
        Get medication reminders for a specific pet
        """
        query = supabase.table("medication_reminders").select("*").eq("pet_id", pet_id).eq("user_id", user_id)
        
        if active_only:
            query = query.eq("is_active", True)
        
        query = query.order("created_at", desc=True).range(offset, offset + limit - 1)
        
        response = query.execute()
        
        if not response.data:
            return []
        
        # Parse reminder times from JSON
        for reminder in response.data:
            if reminder.get("reminder_times"):
                try:
                    reminder["reminder_times"] = json.loads(reminder["reminder_times"])
                except (json.JSONDecodeError, TypeError):
                    reminder["reminder_times"] = []
        
        return response.data
    
    @staticmethod
    async def get_medication_reminders_for_health_event(
        health_event_id: str,
        user_id: str,
        supabase,
        limit: int = 50,
        offset: int = 0
    ) -> List[Dict[str, Any]]:
        """
        Get medication reminders for a specific health event
        """
        query = supabase.table("medication_reminders").select("*").eq("health_event_id", health_event_id).eq("user_id", user_id)
        query = query.order("created_at", desc=True).range(offset, offset + limit - 1)
        
        response = query.execute()
        
        if not response.data:
            return []
        
        # Parse reminder times from JSON
        for reminder in response.data:
            if reminder.get("reminder_times"):
                try:
                    reminder["reminder_times"] = json.loads(reminder["reminder_times"])
                except (json.JSONDecodeError, TypeError):
                    reminder["reminder_times"] = []
        
        return response.data
    
    @staticmethod
    async def get_medication_reminder_by_id(
        reminder_id: str,
        user_id: str,
        supabase
    ) -> Optional[Dict[str, Any]]:
        """
        Get a specific medication reminder by ID
        """
        response = supabase.table("medication_reminders").select("*").eq("id", reminder_id).eq("user_id", user_id).execute()
        
        if not response.data:
            return None
        
        reminder = response.data[0]
        
        # Parse reminder times from JSON
        if reminder.get("reminder_times"):
            try:
                reminder["reminder_times"] = json.loads(reminder["reminder_times"])
            except (json.JSONDecodeError, TypeError):
                reminder["reminder_times"] = []
        
        return reminder
    
    @staticmethod
    async def update_medication_reminder(
        reminder_id: str,
        updates: MedicationReminderUpdate,
        user_id: str,
        supabase
    ) -> Optional[Dict[str, Any]]:
        """
        Update a medication reminder
        """
        # Prepare update data
        update_data = {}
        
        if updates.medication_name is not None:
            update_data["medication_name"] = updates.medication_name
        
        if updates.dosage is not None:
            update_data["dosage"] = updates.dosage
        
        if updates.frequency is not None:
            update_data["frequency"] = updates.frequency.value
        
        if updates.reminder_times is not None:
            update_data["reminder_times"] = json.dumps([rt.model_dump() for rt in updates.reminder_times])
        
        if updates.start_date is not None:
            update_data["start_date"] = updates.start_date.isoformat()
        
        if updates.end_date is not None:
            update_data["end_date"] = updates.end_date.isoformat() if updates.end_date else None
        
        if updates.is_active is not None:
            update_data["is_active"] = updates.is_active
        
        if not update_data:
            # No updates to make
            return await MedicationReminderService.get_medication_reminder_by_id(reminder_id, user_id, supabase)
        
        # Update in database
        response = supabase.table("medication_reminders").update(update_data).eq("id", reminder_id).eq("user_id", user_id).execute()
        
        if not response.data:
            return None
        
        reminder = response.data[0]
        
        # Parse reminder times from JSON
        if reminder.get("reminder_times"):
            try:
                reminder["reminder_times"] = json.loads(reminder["reminder_times"])
            except (json.JSONDecodeError, TypeError):
                reminder["reminder_times"] = []
        
        return reminder
    
    @staticmethod
    async def delete_medication_reminder(
        reminder_id: str,
        user_id: str,
        supabase
    ) -> bool:
        """
        Delete a medication reminder
        """
        response = supabase.table("medication_reminders").delete().eq("id", reminder_id).eq("user_id", user_id).execute()
        
        return len(response.data) > 0
    
    @staticmethod
    async def activate_medication_reminder(
        reminder_id: str,
        user_id: str,
        supabase
    ) -> bool:
        """
        Activate a medication reminder
        """
        response = supabase.table("medication_reminders").update({"is_active": True}).eq("id", reminder_id).eq("user_id", user_id).execute()
        
        return len(response.data) > 0
    
    @staticmethod
    async def deactivate_medication_reminder(
        reminder_id: str,
        user_id: str,
        supabase
    ) -> bool:
        """
        Deactivate a medication reminder
        """
        response = supabase.table("medication_reminders").update({"is_active": False}).eq("id", reminder_id).eq("user_id", user_id).execute()
        
        return len(response.data) > 0
    
    @staticmethod
    async def get_medication_reminders_count_for_pet(
        pet_id: str,
        user_id: str,
        supabase,
        active_only: bool = True
    ) -> int:
        """
        Get count of medication reminders for a pet
        """
        query = supabase.table("medication_reminders").select("id", count="exact").eq("pet_id", pet_id).eq("user_id", user_id)
        
        if active_only:
            query = query.eq("is_active", True)
        
        response = query.execute()
        
        return response.count or 0
    
    @staticmethod
    async def get_medication_reminders_count_for_health_event(
        health_event_id: str,
        user_id: str,
        supabase
    ) -> int:
        """
        Get count of medication reminders for a health event
        """
        response = supabase.table("medication_reminders").select("id", count="exact").eq("health_event_id", health_event_id).eq("user_id", user_id).execute()
        
        return response.count or 0
