"""
RevenueCat Subscription Service

Handles subscription database operations and user protection logic.
Extracted from revenuecat_service.py for better single responsibility.

This service manages:
- Subscription record updates in database
- User role management based on subscription status
- Protection of admin/developer accounts from downgrades
"""

from typing import Optional, Dict, Any
from supabase import Client
import logging

from app.shared.services.datetime_service import DateTimeService
from app.shared.services.database_operation_service import DatabaseOperationService
from app.shared.utils.async_supabase import execute_async
from app.models.core.user import UserRole
from app.core.config import settings

logger = logging.getLogger(__name__)


class RevenueCatSubscriptionService:
    """
    Service for managing subscription database operations and user protection
    
    Responsibilities:
    - Update subscription records in database
    - Manage user role changes
    - Protect admin/developer accounts from automatic downgrades
    """
    
    def __init__(self, supabase: Client):
        """
        Initialize RevenueCat subscription service
        
        Args:
            supabase: Authenticated Supabase client (for RLS compliance)
        """
        self.supabase = supabase
    
    async def update_subscription(
        self,
        user_id: str,
        status: str,
        product_id: str,
        entitlement_id: str,
        expires_at: Optional[str] = None
    ) -> None:
        """
        Update or create subscription record in database
        
        Args:
            user_id: User ID
            status: Subscription status
            product_id: Product identifier
            entitlement_id: Entitlement identifier (not stored in DB, kept for API compatibility)
            expires_at: Expiration datetime (ISO format) - stored as expiration_date in DB
            
        Raises:
            Exception: If subscription update fails
        """
        try:
            # Check if subscription exists for this user
            existing_response = await execute_async(
                lambda: self.supabase.table("subscriptions").select("*").eq("user_id", user_id).execute()
            )
            
            # Determine tier from product_id
            tier = "monthly"  # default
            if "weekly" in product_id.lower():
                tier = "weekly"
            elif "yearly" in product_id.lower() or "annual" in product_id.lower():
                tier = "yearly"
            
            subscription_data = {
                "user_id": user_id,
                "status": status,
                "product_id": product_id,
                "tier": tier,
                "updated_at": DateTimeService.now_iso()
            }
            
            # Map expires_at to expiration_date (correct column name)
            if expires_at:
                subscription_data["expiration_date"] = expires_at
            
            # If subscription exists, update it; otherwise create new
            db_service = DatabaseOperationService(self.supabase)
            
            if existing_response.data and len(existing_response.data) > 0:
                # Update existing subscription using centralized service
                existing_sub = existing_response.data[0]
                subscription_id = existing_sub.get("id")
                
                if subscription_id:
                    # Use DatabaseOperationService for update
                    await db_service.update_with_timestamp(
                        "subscriptions",
                        subscription_id,
                        subscription_data
                    )
                else:
                    # Fallback: update by original_transaction_id (less ideal but handles edge cases)
                    original_transaction_id = existing_sub.get("original_transaction_id")
                    if original_transaction_id:
                        # Direct update for this edge case - add updated_at manually
                        subscription_data["updated_at"] = DateTimeService.now_iso()
                        response = await execute_async(
                            lambda: self.supabase.table("subscriptions").update(subscription_data).eq(
                                "original_transaction_id", original_transaction_id
                            ).execute()
                        )
                    else:
                        # Fallback to user_id
                        subscription_data["updated_at"] = DateTimeService.now_iso()
                        response = await execute_async(
                            lambda: self.supabase.table("subscriptions").update(subscription_data).eq(
                                "user_id", user_id
                            ).execute()
                        )
            else:
                # Create new subscription using centralized service - need required fields
                subscription_data["purchase_date"] = DateTimeService.now_iso()
                subscription_data["original_transaction_id"] = f"rc_{user_id}_{int(DateTimeService.now().timestamp())}"
                subscription_data["latest_transaction_id"] = subscription_data["original_transaction_id"]
                subscription_data["auto_renew"] = True
                
                await db_service.insert_with_timestamps("subscriptions", subscription_data)
            
            # Verify the update succeeded
            verify_response = await execute_async(
                lambda: self.supabase.table("subscriptions").select("status, product_id").eq("user_id", user_id).execute()
            )
            if verify_response.data:
                verified_sub = verify_response.data[0]
                if verified_sub.get("status") == status:
                    logger.info(f"✅ Successfully updated subscription for user {user_id}: status={status}, product={product_id}")
                else:
                    logger.warning(f"⚠️ Subscription update verification failed for user {user_id}. Expected status {status}, got {verified_sub.get('status')}")
            else:
                logger.error(f"❌ Failed to verify subscription update for user {user_id}")
                raise Exception(f"Subscription update verification failed for user {user_id}")
        
        except Exception as e:
            logger.error(f"Error updating subscription in database for user {user_id}: {str(e)}", exc_info=True)
            raise
    
    async def is_admin_user(self, user_id: str) -> bool:
        """
        Check if a user is an admin user with full access without subscription
        
        Admin users are defined by:
        1. Email in PROTECTED_PREMIUM_EMAILS environment variable
        2. Premium role without active RevenueCat subscription (manually set)
        
        Args:
            user_id: User ID to check
            
        Returns:
            True if user is an admin user
        """
        return await self._should_protect_from_downgrade(user_id)
    
    async def _should_protect_from_downgrade(self, user_id: str) -> bool:
        """
        Check if a user should be protected from automatic downgrades
        This protects admin/developer accounts from RevenueCat webhook downgrades
        
        Admin users have full premium access without requiring a subscription.
        This is useful for:
        - Developer accounts
        - Internal team members
        - Beta testers
        - Support staff
        
        Args:
            user_id: User ID to check
            
        Returns:
            True if user should be protected from downgrades (is an admin user)
        """
        try:
            logger.info(f"🔍 Checking downgrade protection for user {user_id}")
            
            # First check if user has bypass_subscription flag set
            user_response = await execute_async(
                lambda: self.supabase.table("users").select("email, role, bypass_subscription").eq("id", user_id).execute()
            )
            
            if user_response.data:
                bypass_subscription = user_response.data[0].get("bypass_subscription", False)
                if bypass_subscription:
                    logger.info(f"🛡️ User {user_id} is protected from downgrade (bypass_subscription flag is set)")
                    return True
            
            # Get user email to check against protected list
            if not user_response.data:
                user_response = await execute_async(
                    lambda: self.supabase.table("users").select("email, role").eq("id", user_id).execute()
                )
            
            if not user_response.data:
                logger.warning(f"⚠️ User {user_id} not found in database - cannot protect")
                return False
            
            user_email = user_response.data[0].get("email", "").lower()
            current_role = user_response.data[0].get("role", "free")
            
            logger.info(f"🔍 User {user_id} ({user_email}) current role: {current_role}")
            
            # Get protected emails from environment variable
            protected_emails = []
            if hasattr(settings, 'protected_premium_emails') and settings.protected_premium_emails:
                # Handle both string and list formats
                if isinstance(settings.protected_premium_emails, str):
                    protected_emails = [email.strip() for email in settings.protected_premium_emails.split(",") if email.strip()]
                elif isinstance(settings.protected_premium_emails, list):
                    protected_emails = [email.strip() for email in settings.protected_premium_emails if email.strip()]
            
            # Also add hardcoded protected emails (for development/testing)
            # You can add your email here as a fallback
            hardcoded_protected = [
                # Add your email addresses here if needed
                # Example: "developer@yourcompany.com",
                # Example: "@yourcompany.com",  # Protects entire domain
            ]
            protected_emails.extend(hardcoded_protected)
            
            logger.info(f"🔍 Protected emails list: {protected_emails}")
            
            # Check if user email matches protected list FIRST
            # This works even if user was already downgraded to free
            for protected in protected_emails:
                if protected.startswith("@"):
                    # Domain protection
                    if user_email.endswith(protected.lower()):
                        logger.info(f"🛡️ User {user_id} ({user_email}) is PROTECTED from downgrade (domain match: {protected})")
                        return True
                else:
                    # Exact email match
                    if user_email == protected.lower():
                        logger.info(f"🛡️ User {user_id} ({user_email}) is PROTECTED from downgrade (exact match: {protected})")
                        return True
            
            # ALWAYS protect users who are already premium and don't have active RevenueCat subscriptions
            # This prevents RevenueCat from downgrading manually set premium accounts
            # This is critical for developer/admin accounts
            # NOTE: This only works if user is STILL premium - if already downgraded, check protected emails above
            if current_role == "premium":
                # Check if there's an active subscription from RevenueCat
                subscription_response = await execute_async(
                    lambda: self.supabase.table("subscriptions").select("status, product_id").eq("user_id", user_id).execute()
                )
                has_active_subscription = False
                has_any_subscription = False
                
                if subscription_response.data:
                    has_any_subscription = True
                    for sub in subscription_response.data:
                        sub_status = sub.get("status", "").lower()
                        product_id = sub.get("product_id", "")
                        
                        # Skip permanent premium markers (created by our script)
                        if product_id == "permanent_premium":
                            logger.info(f"🛡️ User {user_id} ({user_email}) is protected from downgrade (has permanent_premium marker)")
                            return True
                        
                        # Check for active subscriptions (only RevenueCat-managed subscriptions)
                        # If status is active/grace_period/billing_retry, user has active RevenueCat subscription
                        if sub_status in ["active", "grace_period", "billing_retry"]:
                            has_active_subscription = True
                            break
                
                # If user is premium but has no active RevenueCat subscription, ALWAYS protect
                # This means the premium status was manually set and should be preserved
                if not has_active_subscription:
                    if not has_any_subscription:
                        logger.info(f"🛡️ User {user_id} ({user_email}) is PROTECTED from downgrade (premium with no subscriptions - manually set)")
                    else:
                        logger.info(f"🛡️ User {user_id} ({user_email}) is PROTECTED from downgrade (premium with only expired/cancelled subscriptions - manually set)")
                    return True
            
            logger.info(f"❌ User {user_id} ({user_email}) is NOT protected from downgrade")
            return False
            
        except Exception as e:
            logger.error(f"❌ ERROR checking downgrade protection for user {user_id}: {str(e)}", exc_info=True)
            # On error, don't protect (fail open)
            return False
    
    async def update_user_role(self, user_id: str, role: UserRole, allow_downgrade: bool = True) -> None:
        """
        Update user's role in database
        
        DEPRECATED: Use UserRoleManager.update_user_role() instead.
        This method is kept for backward compatibility but now delegates to UserRoleManager.
        
        Args:
            user_id: User ID
            role: New user role
            allow_downgrade: If False, prevents downgrading from premium to free (ignored, always checked)
        """
        from app.shared.services.user_role_manager import UserRoleManager
        
        role_manager = UserRoleManager(self.supabase)
        reason = f"RevenueCat service update (allow_downgrade={allow_downgrade})"
        await role_manager.update_user_role(user_id, role, reason)

