"""
Centralized user role management service

This is the SINGLE SOURCE OF TRUTH for all user role updates.
All role changes must go through this service to ensure:
1. Bypass subscription flag is always checked first
2. Protected users are never downgraded
3. Consistency across the entire application
"""

import logging
from app.shared.services.datetime_service import DateTimeService
from app.shared.services.database_operation_service import DatabaseOperationService
from typing import Optional
from supabase import Client

from app.models.user import UserRole
from app.services.revenuecat_service import RevenueCatService

logger = logging.getLogger(__name__)


class UserRoleManager:
    """
    Centralized manager for all user role updates
    
    This class ensures that:
    - Bypass subscription flag is always checked first
    - Protected users are never downgraded
    - All role updates are consistent and logged
    """
    
    def __init__(self, supabase: Client):
        """
        Initialize user role manager
        
        Args:
            supabase: Supabase client instance
        """
        self.supabase = supabase
        self.revenuecat_service = RevenueCatService(supabase)
    
    async def update_user_role(
        self, 
        user_id: str, 
        new_role: UserRole, 
        reason: Optional[str] = None
    ) -> bool:
        """
        Update user's role in database with bypass protection
        
        This is the ONLY method that should be used to update user roles.
        It ensures bypass_subscription flag is always respected.
        
        Args:
            user_id: User ID to update
            new_role: New role to set (UserRole.FREE or UserRole.PREMIUM)
            reason: Optional reason for the role change (for logging)
            
        Returns:
            True if role was updated, False if update was blocked
            
        Raises:
            Exception: If update fails
        """
        try:
            # Step 1: Check if user has bypass_subscription flag
            user_response = self.supabase.table("users").select(
                "role, bypass_subscription"
            ).eq("id", user_id).execute()
            
            if not user_response.data:
                logger.error(f"❌ User {user_id} not found - cannot update role")
                raise ValueError(f"User {user_id} not found")
            
            user_data = user_response.data[0]
            current_role = user_data.get("role", "free")
            bypass_subscription = user_data.get("bypass_subscription", False)
            
            # Step 2: If user has bypass flag, NEVER downgrade to free
            if bypass_subscription and new_role == UserRole.FREE:
                logger.warning(
                    f"🛡️ BLOCKED role downgrade for user {user_id} - "
                    f"bypass_subscription is enabled. Current role: {current_role}, "
                    f"Attempted role: {new_role.value}, Reason: {reason or 'N/A'}"
                )
                return False
            
            # Step 3: If user has bypass flag and we're setting premium, ensure it's set
            if bypass_subscription and new_role == UserRole.PREMIUM:
                # User already has bypass, just ensure role is premium
                if current_role != "premium":
                    logger.info(
                        f"🔧 User {user_id} has bypass_subscription but role is {current_role}. "
                        f"Updating to premium."
                    )
                else:
                    logger.debug(
                        f"✅ User {user_id} already has premium role with bypass_subscription"
                    )
            
            # Step 4: Check additional protection (protected emails, etc.)
            # This is a fallback for users protected via email but without bypass flag
            if new_role == UserRole.FREE:
                if self.revenuecat_service._should_protect_from_downgrade(user_id):
                    logger.warning(
                        f"🛡️ BLOCKED role downgrade for user {user_id} - "
                        f"user is protected (email-based protection). "
                        f"Current role: {current_role}, Reason: {reason or 'N/A'}"
                    )
                    return False
            
            # Step 5: Perform the role update using centralized service
            # allow_role_update=True because we've already checked bypass flag above
            db_service = DatabaseOperationService(self.supabase)
            result = db_service.update_with_timestamp(
                "users",
                user_id,
                {"role": new_role.value},
                allow_role_update=True
            )
            
            # Step 6: Verify the update succeeded
            updated_role = result.get("role") if result else None
            
            if updated_role == new_role.value:
                logger.info(
                    f"✅ Successfully updated user {user_id} role to {new_role.value}. "
                    f"Reason: {reason or 'N/A'}"
                )
                return True
            else:
                logger.error(
                    f"❌ Role update verification failed for user {user_id}. "
                    f"Expected {new_role.value}, got {updated_role}"
                )
                raise Exception(
                    f"Role update verification failed for user {user_id}"
                )
        
        except Exception as e:
            logger.error(
                f"❌ Error updating user role for user {user_id}: {str(e)}", 
                exc_info=True
            )
            raise
    
    async def ensure_premium_for_bypass_user(self, user_id: str) -> bool:
        """
        Ensure user with bypass_subscription flag has premium role
        
        This is called to fix any inconsistencies where bypass users
        might have been incorrectly downgraded.
        
        Args:
            user_id: User ID to check and fix
            
        Returns:
            True if role was updated, False if already correct
        """
        try:
            user_response = self.supabase.table("users").select(
                "role, bypass_subscription"
            ).eq("id", user_id).execute()
            
            if not user_response.data:
                return False
            
            user_data = user_response.data[0]
            current_role = user_data.get("role", "free")
            bypass_subscription = user_data.get("bypass_subscription", False)
            
            if bypass_subscription and current_role != "premium":
                logger.warning(
                    f"🔧 Fixing role for bypass user {user_id}: "
                    f"bypass_subscription=True but role={current_role}. Setting to premium."
                )
                # Use the centralized update method
                return await self.update_user_role(
                    user_id, UserRole.PREMIUM, "Bypass user role fix"
                )
            
            return False
        
        except Exception as e:
            logger.error(
                f"Error ensuring premium for bypass user {user_id}: {str(e)}"
            )
            return False
    
    def has_bypass_subscription(self, user_id: str) -> bool:
        """
        Check if user has bypass_subscription flag enabled
        
        Args:
            user_id: User ID to check
            
        Returns:
            True if user has bypass_subscription enabled
        """
        try:
            user_response = self.supabase.table("users").select(
                "bypass_subscription"
            ).eq("id", user_id).execute()
            
            if user_response.data:
                return user_response.data[0].get("bypass_subscription", False)
            
            return False
        
        except Exception as e:
            logger.error(f"Error checking bypass flag for user {user_id}: {str(e)}")
            return False

