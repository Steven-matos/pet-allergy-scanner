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
                    
                    # Downgrade user to free
                    await self._update_user_role(user_id, UserRole.FREE)
                    
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
                await self._update_user_role(from_user_id, UserRole.FREE)
            
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
            entitlement_id: Entitlement identifier
            expires_at: Expiration datetime (ISO format)
        """
        try:
            subscription_data = {
                "user_id": user_id,
                "status": status,
                "product_id": product_id,
                "entitlement_id": entitlement_id,
                "updated_at": datetime.now(timezone.utc).isoformat()
            }
            
            if expires_at:
                subscription_data["expires_at"] = expires_at
            
            # Upsert subscription record
            self.supabase.table("subscriptions").upsert(
                subscription_data,
                on_conflict="user_id"
            ).execute()
            
        
        except Exception as e:
            logger.error(f"Error updating subscription in database: {str(e)}")
            raise
    
    async def _update_user_role(self, user_id: str, role: UserRole) -> None:
        """
        Update user's role in database
        
        Args:
            user_id: User ID
            role: New user role
        """
        try:
            self.supabase.table("users").update({
                "role": role.value,
                "updated_at": datetime.now(timezone.utc).isoformat()
            }).eq("id", user_id).execute()
            
        
        except Exception as e:
            logger.error(f"Error updating user role: {str(e)}")
            raise

