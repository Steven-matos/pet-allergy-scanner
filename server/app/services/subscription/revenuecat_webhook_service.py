"""
RevenueCat Webhook Service

Handles all RevenueCat webhook events for subscription lifecycle management.
Extracted from revenuecat_service.py for better single responsibility.

Documentation: https://www.revenuecat.com/docs/webhooks
"""

from typing import Dict, Any
from supabase import Client
import logging

from app.models.core.user import UserRole
from app.services.subscription.revenuecat_subscription_service import RevenueCatSubscriptionService

logger = logging.getLogger(__name__)


class RevenueCatWebhookService:
    """
    Service for handling RevenueCat webhook events
    
    Responsibilities:
    - Process webhook events from RevenueCat
    - Update subscription status based on events
    - Manage user role changes based on subscription status
    """
    
    # Entitlement identifier from RevenueCat dashboard
    PREMIUM_ENTITLEMENT = "pro_user"
    
    def __init__(self, supabase: Client):
        """
        Initialize RevenueCat webhook service
        
        Args:
            supabase: Authenticated Supabase client (for RLS compliance)
        """
        self.supabase = supabase
        self.subscription_service = RevenueCatSubscriptionService(supabase)
    
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
                    await self.subscription_service.update_subscription(
                        user_id=user_id,
                        status="active",
                        product_id=product_id,
                        expires_at=expires_date,
                        entitlement_id=self.PREMIUM_ENTITLEMENT
                    )
                    
                    # Upgrade user role to premium
                    await self.subscription_service.update_user_role(user_id, UserRole.PREMIUM)
                    
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
                await self.subscription_service.update_subscription(
                    user_id=user_id,
                    status="active",
                    product_id=product_id,
                    expires_at=expires_date,
                    entitlement_id=self.PREMIUM_ENTITLEMENT
                )
                
                # Ensure user has premium role
                await self.subscription_service.update_user_role(user_id, UserRole.PREMIUM)
        
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
            await self.subscription_service.update_subscription(
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
            await self.subscription_service.update_subscription(
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
                    await self.subscription_service.update_subscription(
                        user_id=user_id,
                        status="expired",
                        product_id=product_id,
                        entitlement_id=self.PREMIUM_ENTITLEMENT
                    )
                    
                    # Downgrade user to free, but check if user should be protected
                    # Set allow_downgrade=False to check protection before downgrading
                    await self.subscription_service.update_user_role(user_id, UserRole.FREE, allow_downgrade=False)
                    
                    # Check if downgrade was actually applied
                    from app.shared.utils.async_supabase import execute_async
                    verify_response = await execute_async(
                        lambda: self.supabase.table("users").select("role").eq("id", user_id).execute()
                    )
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
            await self.subscription_service.update_subscription(
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
            await self.subscription_service.update_subscription(
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
                await self.subscription_service.update_user_role(from_user_id, UserRole.FREE, allow_downgrade=False)
            
            await self.subscription_service.update_user_role(to_user_id, UserRole.PREMIUM)
        
        except Exception as e:
            logger.error(f"Error handling transfer: {str(e)}", exc_info=True)
            raise

