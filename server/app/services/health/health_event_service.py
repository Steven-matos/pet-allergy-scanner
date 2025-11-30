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
        
        # Initialize diagnostic variables
        pet_owner_id = None
        event_count = 0
        
        # First, verify pet ownership (RLS requires this)
        try:
            pet_check = supabase.table("pets").select("id, user_id").eq("id", pet_id).execute()
            if not pet_check.data:
                logger.error(f"   ❌ Pet {pet_id} not found!")
                print(f"   ❌ Pet {pet_id} not found!")
                return []
            
            pet_owner_id = pet_check.data[0].get('user_id')
            logger.info(f"   Pet owner: {pet_owner_id}, Requested user: {user_id}")
            print(f"   Pet owner: {pet_owner_id}, Requested user: {user_id}")
            
            if pet_owner_id != user_id:
                logger.error(f"   ❌ Pet ownership mismatch! Pet belongs to {pet_owner_id}, but user is {user_id}")
                print(f"   ❌ Pet ownership mismatch! Pet belongs to {pet_owner_id}, but user is {user_id}")
                return []
        except Exception as e:
            logger.error(f"   ❌ Pet ownership check failed: {e}")
            print(f"   ❌ Pet ownership check failed: {e}")
            return []
        
        # Check if there are ANY events for this pet (bypassing RLS for diagnostic)
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
        
        # Query with RLS - DO NOT add explicit user_id filter
        # RLS policy automatically filters by auth.uid() = user_id AND verifies pet ownership
        # Adding .eq("user_id", user_id) might conflict with RLS or cause issues
        logger.info(f"   Executing query with RLS: pet_id={pet_id}")
        print(f"🔍 [QUERY] Executing with RLS: pet_id={pet_id}")
        
        try:
            # Query WITHOUT explicit user_id filter - let RLS handle it
            # The RLS policy checks: auth.uid() = user_id AND pet belongs to user
            response = supabase.table("health_events").select("*").eq("pet_id", pet_id).order("event_date", desc=True).range(offset, offset + limit - 1).execute()
            
            result_count = len(response.data) if response.data else 0
            logger.info(f"   Events found with RLS: {result_count}")
            print(f"🔍 [QUERY] Results with RLS: {result_count}")
            
            if result_count > 0:
                logger.info(f"✅ [get_health_events_for_pet] Returning {len(response.data)} events")
                print(f"✅ [QUERY] Returning {len(response.data)} events")
                return response.data
            else:
                # If RLS returns 0, try to understand why
                # Check if events exist but RLS is blocking
                logger.warning(f"⚠️ [get_health_events_for_pet] RLS query returned 0 events")
                print(f"⚠️ [QUERY] RLS returned 0 events - checking if events exist...")
                
                # Diagnostic: Check if events exist (we already did this above)
                if event_count > 0:
                    logger.error(f"❌ [get_health_events_for_pet] Events exist ({event_count}) but RLS is blocking them!")
                    print(f"❌ [QUERY] Events exist ({event_count}) but RLS is blocking them!")
                    print(f"   This suggests RLS policy is not working correctly")
                    print(f"   Pet owner: {pet_owner_id}, User: {user_id}, Match: {pet_owner_id == user_id}")
                
        except Exception as e:
            logger.error(f"   Query failed: {e}", exc_info=True)
            print(f"   ❌ Query failed: {e}")
            raise
        
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