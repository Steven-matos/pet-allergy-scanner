"""
Health Event Service

Handles all database operations for health events including CRUD operations,
data validation, and business logic using Supabase client.
"""

from typing import List, Optional, Dict, Any
from uuid import UUID
from datetime import datetime
from supabase import Client

from app.models.health_event import (
    HealthEvent,
    HealthEventCreate,
    HealthEventUpdate,
    HealthEventResponse,
    HealthEventListResponse,
    HealthEventCategory,
    HealthEventType
)
import logging

logger = logging.getLogger(__name__)


class HealthEventService:
    """Service class for health event operations"""

    @staticmethod
    async def create_health_event(
        health_event_create: HealthEventCreate,
        user_id: str,
        supabase: Client
    ) -> Dict[str, Any]:
        """Create a new health event"""

        try:
            # Prepare the health event data
            event_data = {
                "pet_id": health_event_create.pet_id,
                "user_id": user_id,
                "event_type": health_event_create.event_type.value,
                "event_category": health_event_create.event_category.value,
                "title": health_event_create.title,
                "notes": health_event_create.notes,
                "severity_level": health_event_create.severity_level,
                "event_date": health_event_create.event_date.isoformat(),
                "created_at": datetime.utcnow().isoformat(),
                "updated_at": datetime.utcnow().isoformat()
            }

            # Insert into Supabase
            response = supabase.table("health_events").insert(event_data).execute()

            if response.data:
                return response.data[0]
            else:
                raise Exception("Failed to create health event")

        except Exception as e:
            logger.error(f"Error creating health event: {e}")
            raise

    @staticmethod
    async def get_health_event_by_id(
        event_id: str,
        user_id: str,
        supabase: Client
    ) -> Optional[Dict[str, Any]]:
        """Get a specific health event by ID"""

        try:
            response = supabase.table("health_events").select("*").eq("id", event_id).eq("user_id", user_id).execute()

            if response.data:
                return response.data[0]
            return None

        except Exception as e:
            logger.error(f"Error getting health event by ID: {e}")
            return None

    @staticmethod
    async def get_health_events_for_pet(
        pet_id: str,
        user_id: str,
        supabase: Client,
        limit: int = 50,
        offset: int = 0
    ) -> List[Dict[str, Any]]:
        """Get all health events for a specific pet"""

        try:
            response = supabase.table("health_events").select("*").eq("pet_id", pet_id).eq("user_id", user_id).order("event_date", desc=True).range(offset, offset + limit - 1).execute()

            return response.data if response.data else []

        except Exception as e:
            logger.error(f"Error getting health events for pet: {e}")
            return []

    @staticmethod
    async def get_health_events_by_category(
        pet_id: str,
        category: str,
        user_id: str,
        supabase: Client,
        limit: int = 50,
        offset: int = 0
    ) -> List[Dict[str, Any]]:
        """Get health events for a pet filtered by category"""

        try:
            response = supabase.table("health_events").select("*").eq("pet_id", pet_id).eq("user_id", user_id).eq("event_category", category).order("event_date", desc=True).range(offset, offset + limit - 1).execute()

            return response.data if response.data else []

        except Exception as e:
            logger.error(f"Error getting health events by category: {e}")
            return []

    @staticmethod
    async def update_health_event(
        event_id: str,
        health_event_update: HealthEventUpdate,
        user_id: str,
        supabase: Client
    ) -> Optional[Dict[str, Any]]:
        """Update an existing health event"""

        try:
            # Check if event exists and belongs to user
            existing_event = await HealthEventService.get_health_event_by_id(event_id, user_id, supabase)
            if not existing_event:
                return None

            # Prepare update data
            update_data = {}
            if health_event_update.title is not None:
                update_data["title"] = health_event_update.title
            if health_event_update.notes is not None:
                update_data["notes"] = health_event_update.notes
            if health_event_update.severity_level is not None:
                update_data["severity_level"] = health_event_update.severity_level
            if health_event_update.event_date is not None:
                update_data["event_date"] = health_event_update.event_date.isoformat()

            update_data["updated_at"] = datetime.utcnow().isoformat()

            # Update in Supabase
            response = supabase.table("health_events").update(update_data).eq("id", event_id).eq("user_id", user_id).execute()

            if response.data:
                return response.data[0]
            return None

        except Exception as e:
            logger.error(f"Error updating health event: {e}")
            return None

    @staticmethod
    async def delete_health_event(
        event_id: str,
        user_id: str,
        supabase: Client
    ) -> bool:
        """Delete a health event"""

        try:
            # Check if event exists and belongs to user
            existing_event = await HealthEventService.get_health_event_by_id(event_id, user_id, supabase)
            if not existing_event:
                return False

            # Delete from Supabase
            response = supabase.table("health_events").delete().eq("id", event_id).eq("user_id", user_id).execute()

            return len(response.data) > 0 if response.data else False

        except Exception as e:
            logger.error(f"Error deleting health event: {e}")
            return False

    @staticmethod
    async def get_health_events_count_for_pet(
        pet_id: str,
        user_id: str,
        supabase: Client
    ) -> int:
        """Get total count of health events for a pet"""

        try:
            response = supabase.table("health_events").select("id", count="exact").eq("pet_id", pet_id).eq("user_id", user_id).execute()

            return response.count if response.count is not None else 0

        except Exception as e:
            logger.error(f"Error getting health events count: {e}")
            return 0

    @staticmethod
    async def get_recent_health_events(
        user_id: str,
        supabase: Client,
        limit: int = 10
    ) -> List[Dict[str, Any]]:
        """Get recent health events across all user's pets"""

        try:
            response = supabase.table("health_events").select("*").eq("user_id", user_id).order("event_date", desc=True).limit(limit).execute()

            return response.data if response.data else []

        except Exception as e:
            logger.error(f"Error getting recent health events: {e}")
            return []

    @staticmethod
    async def get_health_events_by_date_range(
        pet_id: str,
        user_id: str,
        start_date: datetime,
        end_date: datetime,
        supabase: Client
    ) -> List[Dict[str, Any]]:
        """Get health events within a date range"""

        try:
            response = supabase.table("health_events").select("*").eq("pet_id", pet_id).eq("user_id", user_id).gte("event_date", start_date.isoformat()).lte("event_date", end_date.isoformat()).order("event_date", desc=True).execute()

            return response.data if response.data else []

        except Exception as e:
            logger.error(f"Error getting health events by date range: {e}")
            return []

    @staticmethod
    async def get_health_events_by_severity(
        pet_id: str,
        user_id: str,
        min_severity: int,
        supabase: Client
    ) -> List[Dict[str, Any]]:
        """Get health events with severity level >= min_severity"""

        try:
            response = supabase.table("health_events").select("*").eq("pet_id", pet_id).eq("user_id", user_id).gte("severity_level", min_severity).order("event_date", desc=True).execute()

            return response.data if response.data else []

        except Exception as e:
            logger.error(f"Error getting health events by severity: {e}")
            return []
