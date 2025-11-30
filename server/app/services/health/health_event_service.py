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
from app.utils.logging_config import get_logger

logger = get_logger(__name__)


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
        logger.info(f"🔍 [get_health_events_for_pet] Querying health events")
        logger.info(f"   pet_id: {pet_id}")
        logger.info(f"   user_id: {user_id}")
        logger.info(f"   limit: {limit}, offset: {offset}")
        
        # First, check if there are ANY events for this pet (without user_id filter)
        # Use service role client to bypass RLS for diagnostic purposes
        try:
            from app.shared.services.supabase_auth_service import SupabaseAuthService
            service_client = SupabaseAuthService.create_service_role_client()
            all_events_check = service_client.table("health_events").select("id, pet_id, user_id, title, event_type").eq("pet_id", pet_id).execute()
            event_count = len(all_events_check.data) if all_events_check.data else 0
            logger.info(f"   Events found for pet_id (any user, bypassing RLS): {event_count}")
            print(f"🔍 [DIAGNOSTIC] Events found for pet_id (bypassing RLS): {event_count}")
            if all_events_check.data:
                for event in all_events_check.data[:3]:  # Log first 3
                    logger.info(f"   Sample event: id={event.get('id')}, pet_id={event.get('pet_id')}, user_id={event.get('user_id')}, title={event.get('title')}")
                    print(f"   Sample: id={event.get('id')}, user_id={event.get('user_id')}, title={event.get('title')}")
                    # Check if user_id matches
                    if event.get('user_id') != user_id:
                        logger.warning(f"   ⚠️ User ID mismatch! Event user_id={event.get('user_id')}, requested user_id={user_id}")
                        print(f"   ⚠️ User ID mismatch! Event has {event.get('user_id')}, querying for {user_id}")
        except Exception as e:
            logger.warning(f"   Could not check events without RLS: {e}")
            print(f"   ❌ Diagnostic query failed: {e}")
        
        # Now check with user_id filter (with RLS)
        logger.info(f"   Executing query with RLS: pet_id={pet_id}, user_id={user_id}")
        print(f"🔍 [QUERY] Executing with RLS: pet_id={pet_id}, user_id={user_id}")
        
        # Try query WITHOUT explicit user_id filter first - RLS should handle it
        # RLS policy should automatically filter by auth.uid(), so we might not need .eq("user_id", user_id)
        try:
            # First try without user_id filter (RLS should handle it)
            response = supabase.table("health_events").select("*").eq("pet_id", pet_id).order("event_date", desc=True).range(offset, offset + limit - 1).execute()
            result_count = len(response.data) if response.data else 0
            logger.info(f"   Events found with RLS only (no user_id filter): {result_count}")
            print(f"🔍 [QUERY] Results with RLS only: {result_count}")
            
            if result_count > 0:
                logger.info(f"✅ [get_health_events_for_pet] Returning {len(response.data)} events (RLS filtered)")
                print(f"✅ [QUERY] Returning {len(response.data)} events (RLS filtered)")
                return response.data
        except Exception as e:
            logger.warning(f"   Query without user_id filter failed: {e}")
            print(f"   ⚠️ Query without user_id filter failed: {e}")
        
        # Fallback: Try with explicit user_id filter
        try:
            response = supabase.table("health_events").select("*").eq("pet_id", pet_id).eq("user_id", user_id).order("event_date", desc=True).range(offset, offset + limit - 1).execute()
            result_count = len(response.data) if response.data else 0
            logger.info(f"   Events found with explicit user_id filter: {result_count}")
            print(f"🔍 [QUERY] Results with explicit user_id: {result_count}")
            
            if result_count > 0:
                logger.info(f"✅ [get_health_events_for_pet] Returning {len(response.data)} events")
                print(f"✅ [QUERY] Returning {len(response.data)} events")
                return response.data
        except Exception as e:
            logger.error(f"   Query with user_id filter failed: {e}")
            print(f"   ❌ Query with user_id filter failed: {e}")
        
        # If we get here, no events found
        logger.warning(f"⚠️ [get_health_events_for_pet] No events found for pet_id={pet_id}, user_id={user_id}")
        print(f"⚠️ [QUERY] No events found - RLS may be blocking or query is incorrect")
        return []
    
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
        
        count = response.count or 0
        logger.info(f"📊 [get_health_events_count_for_pet] Count: {count} for pet_id={pet_id}, user_id={user_id}")
        
        return count