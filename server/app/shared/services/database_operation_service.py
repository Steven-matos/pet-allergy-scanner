"""
Centralized database operation service

This is the SINGLE SOURCE OF TRUTH for:
1. Common database operations (insert, update, delete with timestamps)
2. Consistent error handling for database operations
3. Automatic updated_at timestamp management
4. Standardized response handling

All database operations should use this service for consistency.
"""

import logging
from typing import Optional, Dict, Any, List
from supabase import Client
import asyncio
from datetime import datetime, date

from app.shared.services.datetime_service import DateTimeService
from app.shared.utils.async_supabase import execute_async
from app.core.config import settings

logger = logging.getLogger(__name__)


class DatabaseOperationService:
    """
    Centralized service for common database operations
    
    This ensures:
    - Consistent timestamp handling (created_at, updated_at)
    - Standardized error handling
    - Automatic field management
    - Consistent response format
    """
    
    def __init__(self, supabase: Client):
        """
        Initialize database operation service
        
        Args:
            supabase: Supabase client instance
        """
        self.supabase = supabase
    
    async def insert_with_timestamps(
        self,
        table_name: str,
        data: Dict[str, Any],
        include_created_at: bool = True,
        include_updated_at: bool = True
    ) -> Dict[str, Any]:
        """
        Insert record with automatic timestamp management
        
        Args:
            table_name: Table name
            data: Data to insert
            include_created_at: Whether to add created_at timestamp
            include_updated_at: Whether to add updated_at timestamp
            
        Returns:
            Inserted record data
            
        Raises:
            Exception: If insert fails
        """
        try:
            # Serialize datetime objects to ISO strings for JSON compatibility
            serialized_data = self._serialize_datetime_objects(data)
            
            # Add timestamps if not already present
            if include_created_at and "created_at" not in serialized_data:
                serialized_data["created_at"] = DateTimeService.now_iso()
            if include_updated_at and "updated_at" not in serialized_data:
                serialized_data["updated_at"] = DateTimeService.now_iso()
            
            response = await execute_async(
                lambda: self.supabase.table(table_name).insert(serialized_data).execute()
            )
            
            if not response.data:
                raise Exception(f"Insert failed: No data returned for {table_name}")
            
            logger.debug(f"✅ Inserted record into {table_name}")
            return response.data[0]
        
        except Exception as e:
            logger.error(f"❌ Error inserting into {table_name}: {str(e)}", exc_info=True)
            raise
    
    def _serialize_datetime_objects(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Recursively serialize datetime and date objects to ISO strings
        
        Args:
            data: Dictionary that may contain datetime/date objects
            
        Returns:
            Dictionary with datetime/date objects converted to ISO strings
        """
        serialized = {}
        for key, value in data.items():
            if isinstance(value, datetime):
                # Convert datetime to ISO format string
                serialized[key] = value.isoformat()
            elif isinstance(value, date):
                # Convert date to ISO format string
                serialized[key] = value.isoformat()
            elif isinstance(value, dict):
                # Recursively serialize nested dictionaries
                serialized[key] = self._serialize_datetime_objects(value)
            elif isinstance(value, list):
                # Serialize datetime objects in lists
                serialized[key] = [
                    item.isoformat() if isinstance(item, (datetime, date))
                    else self._serialize_datetime_objects(item) if isinstance(item, dict)
                    else item
                    for item in value
                ]
            else:
                serialized[key] = value
        return serialized
    
    async def update_with_timestamp(
        self,
        table_name: str,
        record_id: str,
        data: Dict[str, Any],
        id_column: str = "id",
        include_updated_at: bool = True,
        allow_role_update: bool = False
    ) -> Dict[str, Any]:
        """
        Update record with automatic updated_at timestamp
        
        Args:
            table_name: Table name
            record_id: Record ID to update
            data: Data to update
            id_column: Column name for ID (default: "id")
            include_updated_at: Whether to add updated_at timestamp
            allow_role_update: If True, allows role updates (only for UserRoleManager)
            
        Returns:
            Updated record data
            
        Raises:
            Exception: If update fails
        """
        try:
            # CRITICAL: Prevent direct role updates that bypass UserRoleManager
            # Role updates MUST go through UserRoleManager.update_user_role()
            if table_name == "users" and "role" in data and not allow_role_update:
                logger.error(
                    f"🚨 SECURITY VIOLATION: Attempted to update role directly via DatabaseOperationService. "
                    f"Role updates MUST go through UserRoleManager.update_user_role(). "
                    f"User ID: {record_id}, Attempted role: {data.get('role')}"
                )
                raise ValueError(
                    "Direct role updates are not allowed. Use UserRoleManager.update_user_role() instead. "
                    "This ensures bypass_subscription flag is always respected."
                )
            
            # Serialize datetime objects to ISO strings for JSON compatibility
            serialized_data = self._serialize_datetime_objects(data)
            
            # Add updated_at if not already present
            if include_updated_at and "updated_at" not in serialized_data:
                serialized_data["updated_at"] = DateTimeService.now_iso()
            
            # Perform the update
            update_response = await execute_async(
                lambda: self.supabase.table(table_name)
                    .update(serialized_data)
                    .eq(id_column, record_id)
                    .execute()
            )
            
            # Fetch the updated record separately since Supabase update doesn't return data by default
            # This ensures we get the complete updated record with all fields
            response = await execute_async(
                lambda: self.supabase.table(table_name)
                    .select("*")
                    .eq(id_column, record_id)
                    .execute()
            )
            
            if not response.data:
                raise Exception(
                    f"Update failed: No data returned for {table_name} "
                    f"record {record_id}"
                )
            
            logger.debug(f"✅ Updated {table_name} record {record_id}")
            return response.data[0]
        
        except Exception as e:
            logger.error(
                f"❌ Error updating {table_name} record {record_id}: {str(e)}",
                exc_info=True
            )
            raise
    
    async def upsert_with_timestamps(
        self,
        table_name: str,
        data: Dict[str, Any],
        conflict_column: str,
        include_created_at: bool = True,
        include_updated_at: bool = True
    ) -> Dict[str, Any]:
        """
        Upsert (insert or update) record with automatic timestamp management
        
        Args:
            table_name: Table name
            data: Data to upsert
            conflict_column: Column to check for conflicts
            include_created_at: Whether to add created_at on insert
            include_updated_at: Whether to add updated_at
            
        Returns:
            Upserted record data
            
        Raises:
            Exception: If upsert fails
        """
        try:
            # Check if record exists
            existing = await execute_async(
                lambda: self.supabase.table(table_name).select("*").eq(
                    conflict_column, data.get(conflict_column)
                ).execute()
            )
            
            if existing.data:
                # Update existing record
                record_id = existing.data[0].get("id")
                return await self.update_with_timestamp(
                    table_name, record_id, data, include_updated_at=include_updated_at
                )
            else:
                # Insert new record
                return await self.insert_with_timestamps(
                    table_name, data,
                    include_created_at=include_created_at,
                    include_updated_at=include_updated_at
                )
        
        except Exception as e:
            logger.error(f"❌ Error upserting into {table_name}: {str(e)}", exc_info=True)
            raise
    
    async def delete_record(
        self,
        table_name: str,
        record_id: str,
        id_column: str = "id"
    ) -> bool:
        """
        Delete record by ID
        
        Args:
            table_name: Table name
            record_id: Record ID to delete
            id_column: Column name for ID (default: "id")
            
        Returns:
            True if deleted, False if not found
            
        Raises:
            Exception: If delete fails
        """
        try:
            # Use .select() to ensure we get the deleted record back
            # This helps verify the delete operation succeeded and RLS allowed it
            response = await execute_async(
                lambda: self.supabase.table(table_name)
                    .delete()
                    .eq(id_column, record_id)
                    .select()  # Request the deleted record back
                    .execute()
            )
            
            # Check if we got data back (means delete succeeded and RLS allowed it)
            deleted = bool(response.data and len(response.data) > 0)
            
            if deleted:
                logger.debug(f"✅ Deleted {table_name} record {record_id}")
            else:
                # Could be: record doesn't exist, RLS blocked it, or already deleted
                logger.warning(
                    f"⚠️ No record found to delete: {table_name} {record_id}. "
                    f"Response data: {response.data}. "
                    f"This could mean the record doesn't exist or RLS blocked the delete."
                )
            
            return deleted
        
        except Exception as e:
            logger.error(
                f"❌ Error deleting {table_name} record {record_id}: {str(e)}",
                exc_info=True
            )
            raise
    
    async def get_by_id(
        self,
        table_name: str,
        record_id: str,
        id_column: str = "id",
        columns: Optional[List[str]] = None
    ) -> Optional[Dict[str, Any]]:
        """
        Get record by ID
        
        Args:
            table_name: Table name
            record_id: Record ID
            id_column: Column name for ID (default: "id")
            columns: Optional list of columns to select (default: all)
            
        Returns:
            Record data or None if not found
            
        Raises:
            Exception: If query fails
        """
        try:
            def _execute_query():
                query = self.supabase.table(table_name).select(
                    ",".join(columns) if columns else "*"
                ).eq(id_column, record_id)
                return query.execute()
            
            response = await execute_async(_execute_query)
            return response.data[0] if response.data else None
        
        except Exception as e:
            logger.error(
                f"❌ Error fetching {table_name} record {record_id}: {str(e)}",
                exc_info=True
            )
            raise

