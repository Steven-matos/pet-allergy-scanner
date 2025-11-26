"""
RevenueCat service for managing subscriptions via webhooks and API

This service handles subscription events from RevenueCat webhooks and provides
methods to query subscription status. It replaces direct App Store receipt validation.

Documentation: 
- Webhooks: https://www.revenuecat.com/docs/webhooks
- API: https://www.revenuecat.com/docs/api-v1
"""

import httpx
from datetime import datetime, timezone
from app.shared.services.datetime_service import DateTimeService
from app.shared.services.database_operation_service import DatabaseOperationService
from typing import Optional, Dict, Any
from fastapi import HTTPException, status
from supabase import Client
import logging

from app.models.user import UserRole
from app.core.config import settings

logger = logging.getLogger(__name__)


class RevenueCatService:
    """Service for managing subscriptions through RevenueCat"""
    
    # RevenueCat API base URL
    API_BASE_URL = "https://api.revenuecat.com/v1"
    
    # Entitlement identifier from your RevenueCat dashboard
    PREMIUM_ENTITLEMENT = "pro_user"
    
    def __init__(self, supabase: Client):
        """
        Initialize RevenueCat service
        
        Args:
            supabase: Supabase client instance
        """
        self.supabase = supabase
        self.api_key = settings.revenuecat_api_key
    
    async def handle_initial_purchase(self, event_data: Dict[str, Any]) -> None:
        """
        Handle INITIAL_PURCHASE event from RevenueCat
        
        Triggered when a user makes their first purchase.
        
        Args:
            event_data: Event data from webhook
        """
        try:
            user_id = event_data.get("app_user_id")
            product_id = event_data.get("product_id")
            entitlements = event_data.get("entitlements", {})
            
            logger.info(f"Initial purchase for user {user_id}: {product_id}")
            
            # Check if pro_user entitlement is active
            if self.PREMIUM_ENTITLEMENT in entitlements:
                entitlement_data = entitlements[self.PREMIUM_ENTITLEMENT]
                
                if entitlement_data.get("is_active"):
                    expires_date = entitlement_data.get("expires_date")
                    
                    # Update user subscription status
                    await self._update_subscription(
                        user_id=user_id,
                        status="active",
                        product_id=product_id,
                        expires_at=expires_date,
                        entitlement_id=self.PREMIUM_ENTITLEMENT
                    )
                    
                    # Upgrade user role to premium
                    await self._update_user_role(user_id, UserRole.PREMIUM)
                    
                    logger.info(f"User {user_id} upgraded to premium")
        
        except Exception as e:
            logger.error(f"Error handling initial purchase: {str(e)}", exc_info=True)
            raise
    
    async def handle_renewal(self, event_data: Dict[str, Any]) -> None:
        """
        Handle RENEWAL event from RevenueCat
        
        Triggered when a subscription auto-renews.
        
        Args:
            event_data: Event data from webhook
        """
        try:
            user_id = event_data.get("app_user_id")
            product_id = event_data.get("product_id")
            entitlements = event_data.get("entitlements", {})
            
            logger.info(f"Subscription renewal for user {user_id}: {product_id}")
            
            if self.PREMIUM_ENTITLEMENT in entitlements:
                entitlement_data = entitlements[self.PREMIUM_ENTITLEMENT]
                expires_date = entitlement_data.get("expires_date")
                
                # Update subscription expiration date
                await self._update_subscription(
                    user_id=user_id,
                    status="active",
                    product_id=product_id,
                    expires_at=expires_date,
                    entitlement_id=self.PREMIUM_ENTITLEMENT
                )
                
                # Ensure user has premium role
                await self._update_user_role(user_id, UserRole.PREMIUM)
        
        except Exception as e:
            logger.error(f"Error handling renewal: {str(e)}", exc_info=True)
            raise
    
    async def handle_cancellation(self, event_data: Dict[str, Any]) -> None:
        """
        Handle CANCELLATION event from RevenueCat
        
        Triggered when a user cancels their subscription.
        Note: User still has access until expiration date.
        
        Args:
            event_data: Event data from webhook
        """
        try:
            user_id = event_data.get("app_user_id")
            product_id = event_data.get("product_id")
            
            logger.info(f"Subscription cancelled for user {user_id}: {product_id}")
            
            # Mark subscription as cancelled (but still active until expiration)
            await self._update_subscription(
                user_id=user_id,
                status="cancelled",
                product_id=product_id,
                entitlement_id=self.PREMIUM_ENTITLEMENT
            )
            
            # Don't downgrade user yet - they have access until expiration
        
        except Exception as e:
            logger.error(f"Error handling cancellation: {str(e)}", exc_info=True)
            raise
    
    async def handle_uncancellation(self, event_data: Dict[str, Any]) -> None:
        """
        Handle UNCANCELLATION event from RevenueCat
        
        Triggered when a user re-enables auto-renew after cancelling.
        
        Args:
            event_data: Event data from webhook
        """
        try:
            user_id = event_data.get("app_user_id")
            product_id = event_data.get("product_id")
            
            logger.info(f"Subscription uncancelled for user {user_id}: {product_id}")
            
            # Restore subscription to active status
            await self._update_subscription(
                user_id=user_id,
                status="active",
                product_id=product_id,
                entitlement_id=self.PREMIUM_ENTITLEMENT
            )
        
        except Exception as e:
            logger.error(f"Error handling uncancellation: {str(e)}", exc_info=True)
            raise
    
    async def handle_non_renewing_purchase(self, event_data: Dict[str, Any]) -> None:
        """
        Handle NON_RENEWING_PURCHASE event from RevenueCat
        
        Triggered for consumable or non-subscription purchases.
        
        Args:
            event_data: Event data from webhook
        """
        try:
            user_id = event_data.get("app_user_id")
            product_id = event_data.get("product_id")
            
            logger.info(f"Non-renewing purchase for user {user_id}: {product_id}")
            
            # Handle one-time purchases if you have them
            # For now, just log it
        
        except Exception as e:
            logger.error(f"Error handling non-renewing purchase: {str(e)}", exc_info=True)
            raise
    
    async def handle_expiration(self, event_data: Dict[str, Any]) -> None:
        """
        Handle EXPIRATION event from RevenueCat
        
        Triggered when a subscription expires (not renewed).
        
        Args:
            event_data: Event data from webhook
        """
        try:
            user_id = event_data.get("app_user_id")
            product_id = event_data.get("product_id")
            entitlements = event_data.get("entitlements", {})
            
            logger.info(f"Subscription expired for user {user_id}: {product_id}")
            
            # Check if pro_user entitlement is no longer active
            if self.PREMIUM_ENTITLEMENT in entitlements:
                entitlement_data = entitlements[self.PREMIUM_ENTITLEMENT]
                
                if not entitlement_data.get("is_active"):
                    # Mark subscription as expired
                    await self._update_subscription(
                        user_id=user_id,
                        status="expired",
                        product_id=product_id,
                        entitlement_id=self.PREMIUM_ENTITLEMENT
                    )
                    
                    # Downgrade user to free, but check if user should be protected
                    # Set allow_downgrade=False to check protection before downgrading
                    await self._update_user_role(user_id, UserRole.FREE, allow_downgrade=False)
                    
                    # Check if downgrade was actually applied
                    verify_response = self.supabase.table("users").select("role").eq("id", user_id).execute()
                    if verify_response.data:
                        final_role = verify_response.data[0].get("role")
                        if final_role == "premium":
                            logger.info(f"🛡️ User {user_id} protected from downgrade - remains premium")
                        else:
                            logger.info(f"User {user_id} downgraded to free")
        
        except Exception as e:
            logger.error(f"Error handling expiration: {str(e)}", exc_info=True)
            raise
    
    async def handle_billing_issue(self, event_data: Dict[str, Any]) -> None:
        """
        Handle BILLING_ISSUE event from RevenueCat
        
        Triggered when there's a billing problem (e.g., card declined).
        
        Args:
            event_data: Event data from webhook
        """
        try:
            user_id = event_data.get("app_user_id")
            product_id = event_data.get("product_id")
            
            logger.warning(f"Billing issue for user {user_id}: {product_id}")
            
            # Mark subscription as in billing retry
            await self._update_subscription(
                user_id=user_id,
                status="billing_issue",
                product_id=product_id,
                entitlement_id=self.PREMIUM_ENTITLEMENT
            )
            
            # Optionally: Send email notification to user
        
        except Exception as e:
            logger.error(f"Error handling billing issue: {str(e)}", exc_info=True)
            raise
    
    async def handle_subscriber_alias(self, event_data: Dict[str, Any]) -> None:
        """
        Handle SUBSCRIBER_ALIAS event from RevenueCat
        
        Triggered when an anonymous user is identified.
        
        Args:
            event_data: Event data from webhook
        """
        try:
            original_app_user_id = event_data.get("original_app_user_id")
            new_app_user_id = event_data.get("new_app_user_id")
            
            logger.info(f"Subscriber alias: {original_app_user_id} -> {new_app_user_id}")
            
            # Transfer subscription data from anonymous ID to identified user
            # This depends on your user identification strategy
        
        except Exception as e:
            logger.error(f"Error handling subscriber alias: {str(e)}", exc_info=True)
            raise
    
    async def handle_subscription_paused(self, event_data: Dict[str, Any]) -> None:
        """
        Handle SUBSCRIPTION_PAUSED event from RevenueCat
        
        Triggered when a subscription is paused (Android only feature).
        
        Args:
            event_data: Event data from webhook
        """
        try:
            user_id = event_data.get("app_user_id")
            product_id = event_data.get("product_id")
            
            logger.info(f"Subscription paused for user {user_id}: {product_id}")
            
            # Mark subscription as paused
            await self._update_subscription(
                user_id=user_id,
                status="paused",
                product_id=product_id,
                entitlement_id=self.PREMIUM_ENTITLEMENT
            )
        
        except Exception as e:
            logger.error(f"Error handling subscription paused: {str(e)}", exc_info=True)
            raise
    
    async def handle_transfer(self, event_data: Dict[str, Any]) -> None:
        """
        Handle TRANSFER event from RevenueCat
        
        Triggered when a subscription is transferred between users.
        
        Args:
            event_data: Event data from webhook
        """
        try:
            from_user_id = event_data.get("transferred_from", [None])[0]
            to_user_id = event_data.get("app_user_id")
            product_id = event_data.get("product_id")
            
            logger.info(f"Subscription transferred from {from_user_id} to {to_user_id}: {product_id}")
            
            # Handle subscription transfer
            if from_user_id:
                # Only downgrade if user is not protected
                await self._update_user_role(from_user_id, UserRole.FREE, allow_downgrade=False)
            
            await self._update_user_role(to_user_id, UserRole.PREMIUM)
        
        except Exception as e:
            logger.error(f"Error handling transfer: {str(e)}", exc_info=True)
            raise
    
    async def get_subscriber_info(self, user_id: str) -> Dict[str, Any]:
        """
        Get subscriber information from RevenueCat API
        
        This queries RevenueCat's REST API for real-time subscription status.
        Note: Webhooks are preferred for updating subscription status.
        
        Args:
            user_id: App user ID
            
        Returns:
            Subscriber information
        """
        if not self.api_key:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="RevenueCat API key not configured"
            )
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    f"{self.API_BASE_URL}/subscribers/{user_id}",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json"
                    },
                    timeout=10.0
                )
                
                if response.status_code == 404:
                    return {"has_subscription": False}
                
                response.raise_for_status()
                data = response.json()
                
                # Extract subscription information
                subscriber = data.get("subscriber", {})
                entitlements = subscriber.get("entitlements", {})
                
                has_premium = (
                    self.PREMIUM_ENTITLEMENT in entitlements and
                    entitlements[self.PREMIUM_ENTITLEMENT].get("expires_date") is not None
                )
                
                return {
                    "has_subscription": has_premium,
                    "entitlements": entitlements,
                    "subscriber": subscriber
                }
        
        except httpx.HTTPError as e:
            logger.error(f"HTTP error querying RevenueCat API: {str(e)}")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Unable to fetch subscription information"
            )
        except Exception as e:
            logger.error(f"Error fetching subscriber info: {str(e)}")
            raise
    
    async def _update_subscription(
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
        """
        try:
            # Check if subscription exists for this user
            existing_response = self.supabase.table("subscriptions").select("*").eq("user_id", user_id).execute()
            
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
                    db_service.update_with_timestamp(
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
                        response = self.supabase.table("subscriptions").update(subscription_data).eq(
                            "original_transaction_id", original_transaction_id
                        ).execute()
                    else:
                        # Fallback to user_id
                        subscription_data["updated_at"] = DateTimeService.now_iso()
                        response = self.supabase.table("subscriptions").update(subscription_data).eq(
                            "user_id", user_id
                        ).execute()
            else:
                # Create new subscription using centralized service - need required fields
                subscription_data["purchase_date"] = DateTimeService.now_iso()
                subscription_data["original_transaction_id"] = f"rc_{user_id}_{int(DateTimeService.now().timestamp())}"
                subscription_data["latest_transaction_id"] = subscription_data["original_transaction_id"]
                subscription_data["auto_renew"] = True
                
                db_service.insert_with_timestamps("subscriptions", subscription_data)
            
            # Verify the update succeeded
            verify_response = self.supabase.table("subscriptions").select("status, product_id").eq("user_id", user_id).execute()
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
    
    def is_admin_user(self, user_id: str) -> bool:
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
        return self._should_protect_from_downgrade(user_id)
    
    def _should_protect_from_downgrade(self, user_id: str) -> bool:
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
            user_response = self.supabase.table("users").select("email, role, bypass_subscription").eq("id", user_id).execute()
            
            if user_response.data:
                bypass_subscription = user_response.data[0].get("bypass_subscription", False)
                if bypass_subscription:
                    logger.info(f"🛡️ User {user_id} is protected from downgrade (bypass_subscription flag is set)")
                    return True
            
            # Get user email to check against protected list
            if not user_response.data:
                user_response = self.supabase.table("users").select("email, role").eq("id", user_id).execute()
            
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
                subscription_response = self.supabase.table("subscriptions").select("status, product_id").eq("user_id", user_id).execute()
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
    
    async def _update_user_role(self, user_id: str, role: UserRole, allow_downgrade: bool = True) -> None:
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

