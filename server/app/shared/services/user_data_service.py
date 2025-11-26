"""
Centralized user data service

This is the SINGLE SOURCE OF TRUTH for:
1. Fetching user data from database
2. Merging auth.users and public.users data
3. Creating users if they don't exist
4. Ensuring consistent user data structure

All user data operations should go through this service.
"""

import logging
from typing import Optional, Dict, Any
from supabase import Client

from app.models.user import User, UserResponse
from app.database import get_supabase_service_role_client
from app.core.config import settings

logger = logging.getLogger(__name__)


class UserDataService:
    """
    Centralized service for all user data operations
    
    This ensures:
    - Consistent user data fetching
    - Proper merging of auth.users and public.users
    - Consistent user creation with proper defaults
    - Single place to update when user schema changes
    """
    
    def __init__(self, supabase: Optional[Client] = None):
        """
        Initialize user data service
        
        Args:
            supabase: Optional Supabase client (uses service role if not provided)
        """
        self.supabase = supabase or get_supabase_service_role_client()
    
    async def get_user_by_id(
        self, 
        user_id: str, 
        create_if_not_exists: bool = False,
        auth_metadata: Optional[Dict[str, Any]] = None
    ) -> Optional[User]:
        """
        Get user by ID from database
        
        Args:
            user_id: User ID to fetch
            create_if_not_exists: If True, create user if not found
            auth_metadata: Optional auth metadata to use for creation
            
        Returns:
            User object or None if not found and not creating
        """
        try:
            response = self.supabase.table("users").select("*").eq("id", user_id).execute()
            
            if response.data:
                return User(**response.data[0])
            
            # User not found - create if requested
            if create_if_not_exists:
                logger.info(f"User {user_id} not found, creating with defaults")
                return await self.create_user(user_id, auth_metadata)
            
            return None
        
        except Exception as e:
            logger.error(f"Error fetching user {user_id}: {str(e)}", exc_info=True)
            raise
    
    async def create_user(
        self,
        user_id: str,
        auth_metadata: Optional[Dict[str, Any]] = None,
        additional_data: Optional[Dict[str, Any]] = None
    ) -> User:
        """
        Create user in public.users table with consistent defaults
        
        Args:
            user_id: User ID
            auth_metadata: Optional auth metadata from Supabase auth
            additional_data: Optional additional fields to set
            
        Returns:
            Created User object
            
        Raises:
            Exception: If creation fails
        """
        try:
            # Extract data from auth_metadata if provided
            user_metadata = auth_metadata.get("user_metadata", {}) if auth_metadata else {}
            
            # Build user data with consistent defaults
            user_data = {
                "id": user_id,
                "email": auth_metadata.get("email", "") if auth_metadata else "",
                "username": user_metadata.get("username"),
                "first_name": user_metadata.get("first_name"),
                "last_name": user_metadata.get("last_name"),
                "role": user_metadata.get("role", "free"),
                "onboarded": False,
                "bypass_subscription": False,  # Consistent default
                "image_url": None,
                "device_token": None
            }
            
            # Merge additional data if provided
            if additional_data:
                user_data.update(additional_data)
            
            # Create user in database using centralized service
            db_service = DatabaseOperationService(self.supabase)
            result = db_service.insert_with_timestamps("users", user_data)
            
            logger.info(f"✅ Created user {user_id} in public.users table")
            return User(**result)
        
        except Exception as e:
            logger.error(f"Error creating user {user_id}: {str(e)}", exc_info=True)
            raise
    
    async def get_merged_user_data(
        self,
        user_id: str,
        auth_metadata: Dict[str, Any]
    ) -> UserResponse:
        """
        Merge data from auth.users and public.users tables
        
        This is the standard way to get complete user data that combines:
        - Email and metadata from auth.users (Supabase Auth)
        - Application-specific data from public.users (our database)
        
        Args:
            user_id: User ID
            auth_metadata: Auth metadata from Supabase auth.users
            
        Returns:
            UserResponse with merged data
        """
        try:
            # Get data from public.users table
            user_response = self.supabase.table("users").select(
                "onboarded, image_url, bypass_subscription, role"
            ).eq("id", user_id).execute()
            
            # Extract public.users data or use defaults
            if user_response.data:
                public_data = user_response.data[0]
                onboarded = public_data.get("onboarded", False)
                image_url = public_data.get("image_url")
                bypass_subscription = public_data.get("bypass_subscription", False)
                role = public_data.get("role", "free")
            else:
                # User doesn't exist in public.users - create them
                logger.info(f"User {user_id} not found in public.users, creating with defaults")
                try:
                    created_user = await self.create_user(user_id, auth_metadata)
                    onboarded = created_user.onboarded
                    image_url = created_user.image_url
                    bypass_subscription = created_user.bypass_subscription if hasattr(created_user, 'bypass_subscription') else False
                    role = created_user.role.value if hasattr(created_user.role, 'value') else created_user.role
                except Exception as create_error:
                    logger.error(f"Error creating user in get_merged_user_data: {create_error}")
                    # Use defaults if creation fails
                    onboarded = False
                    image_url = None
                    bypass_subscription = False
                    role = "free"
            
            # Extract auth metadata
            user_metadata = auth_metadata.get("user_metadata", {})
            
            # Merge the data
            merged_data = {
                "id": user_id,
                "email": auth_metadata.get("email", ""),
                "username": user_metadata.get("username"),
                "first_name": user_metadata.get("first_name"),
                "last_name": user_metadata.get("last_name"),
                "role": role,  # Use role from public.users (more authoritative)
                "onboarded": onboarded,
                "bypass_subscription": bypass_subscription,
                "image_url": image_url,
                "created_at": auth_metadata.get("created_at"),
                "updated_at": auth_metadata.get("updated_at")
            }
            
            return UserResponse(**merged_data)
        
        except Exception as e:
            logger.error(f"Error merging user data for {user_id}: {str(e)}", exc_info=True)
            raise
    
    def get_user_by_id_sync(self, user_id: str) -> Optional[Dict[str, Any]]:
        """
        Synchronous version of get_user_by_id (for non-async contexts)
        
        Args:
            user_id: User ID to fetch
            
        Returns:
            User data dictionary or None
        """
        try:
            response = self.supabase.table("users").select("*").eq("id", user_id).execute()
            return response.data[0] if response.data else None
        except Exception as e:
            logger.error(f"Error fetching user {user_id} (sync): {str(e)}")
            return None

