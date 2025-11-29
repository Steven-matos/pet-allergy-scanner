"""
Health Event Service
Business logic for health event management
"""

from datetime import datetime
from typing import List, Optional, Dict, Any

from app.models.health.health_event import (
    HealthEvent,
    HealthEventCreate,
    HealthEventUpdate,
    HealthEventResponse,
    HealthEventCategory
)
from app.shared.services.database_operation_service import DatabaseOperationService


class HealthEventService:
    """Service for managing health events"""
    
    @staticmethod
    async def create_health_event(
        event_data: HealthEventCreate,
        user_id: str,
        supabase
    ) -> Dict[str, Any]:
        """
        Create a new health event
        """
        # Determine event category from event type
        category_mapping = {
            "vomiting": "digestive",
            "diarrhea": "digestive",
            "shedding": "physical",
            "low_energy": "physical",
            "vaccination": "medical",
            "vet_visit": "medical",
            "medication": "medical",
            "anxiety": "behavioral",
            "other": "physical"
        }
        
        event_category = category_mapping.get(event_data.event_type.value, "physical")
        
        # Prepare event data for database
        db_event = {
            "pet_id": event_data.pet_id,
            "user_id": user_id,
            "event_type": event_data.event_type.value,
            "event_category": event_category,
            "title": event_data.title,
            "notes": event_data.notes,
            "severity_level": event_data.severity_level,
            "event_date": event_data.event_date.isoformat()
        }
        
        # Add documents if provided (convert to PostgreSQL array format)
        if hasattr(event_data, 'documents') and event_data.documents:
            db_event["documents"] = event_data.documents
        else:
            db_event["documents"] = []
        
        # Insert into database using centralized service
        db_service = DatabaseOperationService(supabase)
        return await db_service.insert_with_timestamps("health_events", db_event)
    
    @staticmethod
    async def get_health_events_for_pet(
        pet_id: str,
        user_id: str,
        supabase,
        limit: int = 50,
        offset: int = 0
    ) -> List[Dict[str, Any]]:
        """
        Get health events for a specific pet
        """
        response = supabase.table("health_events").select("*").eq("pet_id", pet_id).eq("user_id", user_id).order("event_date", desc=True).range(offset, offset + limit - 1).execute()
        
        if not response.data:
            return []
        
        return response.data
    
    @staticmethod
    async def get_health_events_by_category(
        pet_id: str,
        category: str,
        user_id: str,
        supabase,
        limit: int = 50,
        offset: int = 0
    ) -> List[Dict[str, Any]]:
        """
        Get health events for a specific pet filtered by category
        """
        response = supabase.table("health_events").select("*").eq("pet_id", pet_id).eq("user_id", user_id).eq("event_category", category).order("event_date", desc=True).range(offset, offset + limit - 1).execute()
        
        if not response.data:
            return []
        
        return response.data
    
    @staticmethod
    async def get_health_event_by_id(
        event_id: str,
        user_id: str,
        supabase
    ) -> Optional[Dict[str, Any]]:
        """
        Get a specific health event by ID
        """
        response = supabase.table("health_events").select("*").eq("id", event_id).eq("user_id", user_id).execute()
        
        if not response.data:
            return None
        
        return response.data[0]
    
    @staticmethod
    async def update_health_event(
        event_id: str,
        updates: HealthEventUpdate,
        user_id: str,
        supabase
    ) -> Optional[Dict[str, Any]]:
        """
        Update a health event
        """
        # Prepare update data
        update_data = {}
        
        if updates.title is not None:
            update_data["title"] = updates.title
        
        if updates.notes is not None:
            update_data["notes"] = updates.notes
        
        if updates.severity_level is not None:
            update_data["severity_level"] = updates.severity_level
        
        if updates.event_date is not None:
            update_data["event_date"] = updates.event_date.isoformat()
        
        if not update_data:
            # No updates to make
            return await HealthEventService.get_health_event_by_id(event_id, user_id, supabase)
        
        # Update in database using centralized service
        db_service = DatabaseOperationService(supabase)
        try:
            return await db_service.update_with_timestamp("health_events", event_id, update_data)
        except Exception:
            return None
    
    @staticmethod
    async def delete_health_event(
        event_id: str,
        user_id: str,
        supabase
    ) -> bool:
        """
        Delete a health event
        """
        response = supabase.table("health_events").delete().eq("id", event_id).eq("user_id", user_id).execute()
        
        return len(response.data) > 0
    
    @staticmethod
    async def get_health_events_count_for_pet(
        pet_id: str,
        user_id: str,
        supabase
    ) -> int:
        """
        Get count of health events for a pet
        """
        response = supabase.table("health_events").select("id", count="exact").eq("pet_id", pet_id).eq("user_id", user_id).execute()
        
        return response.count or 0