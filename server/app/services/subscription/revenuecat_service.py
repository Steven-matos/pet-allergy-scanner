"""
RevenueCat Service (Unified)

Unified service that combines webhook, API, and subscription services.
Maintained for backward compatibility with existing code.

For new code, prefer using the specific services:
- RevenueCatWebhookService for webhook events
- RevenueCatAPIService for API queries
- RevenueCatSubscriptionService for database operations
"""

from typing import Dict, Any
from supabase import Client

from .revenuecat_webhook_service import RevenueCatWebhookService
from .revenuecat_api_service import RevenueCatAPIService
from .revenuecat_subscription_service import RevenueCatSubscriptionService


class RevenueCatService:
    """
    Unified service for managing subscriptions through RevenueCat
    
    This class combines all RevenueCat functionality for backward compatibility.
    It delegates to specialized services:
    - WebhookService: Handles webhook events
    - APIService: Handles API queries
    - SubscriptionService: Handles database operations
    """
    
    def __init__(self, supabase: Client):
        """
        Initialize RevenueCat service
        
        Args:
            supabase: Supabase client instance
        """
        self.supabase = supabase
        self.webhook_service = RevenueCatWebhookService(supabase)
        self.api_service = RevenueCatAPIService(supabase)
        self.subscription_service = RevenueCatSubscriptionService(supabase)
        
        # Expose constants for backward compatibility
        self.PREMIUM_ENTITLEMENT = RevenueCatWebhookService.PREMIUM_ENTITLEMENT
        self.API_BASE_URL = RevenueCatAPIService.API_BASE_URL
    
    # Delegate webhook methods
    async def handle_initial_purchase(self, event_data: Dict[str, Any]) -> None:
        """Handle INITIAL_PURCHASE event"""
        return await self.webhook_service.handle_initial_purchase(event_data)
    
    async def handle_renewal(self, event_data: Dict[str, Any]) -> None:
        """Handle RENEWAL event"""
        return await self.webhook_service.handle_renewal(event_data)
    
    async def handle_cancellation(self, event_data: Dict[str, Any]) -> None:
        """Handle CANCELLATION event"""
        return await self.webhook_service.handle_cancellation(event_data)
    
    async def handle_uncancellation(self, event_data: Dict[str, Any]) -> None:
        """Handle UNCANCELLATION event"""
        return await self.webhook_service.handle_uncancellation(event_data)
    
    async def handle_non_renewing_purchase(self, event_data: Dict[str, Any]) -> None:
        """Handle NON_RENEWING_PURCHASE event"""
        return await self.webhook_service.handle_non_renewing_purchase(event_data)
    
    async def handle_expiration(self, event_data: Dict[str, Any]) -> None:
        """Handle EXPIRATION event"""
        return await self.webhook_service.handle_expiration(event_data)
    
    async def handle_billing_issue(self, event_data: Dict[str, Any]) -> None:
        """Handle BILLING_ISSUE event"""
        return await self.webhook_service.handle_billing_issue(event_data)
    
    async def handle_subscriber_alias(self, event_data: Dict[str, Any]) -> None:
        """Handle SUBSCRIBER_ALIAS event"""
        return await self.webhook_service.handle_subscriber_alias(event_data)
    
    async def handle_subscription_paused(self, event_data: Dict[str, Any]) -> None:
        """Handle SUBSCRIPTION_PAUSED event"""
        return await self.webhook_service.handle_subscription_paused(event_data)
    
    async def handle_transfer(self, event_data: Dict[str, Any]) -> None:
        """Handle TRANSFER event"""
        return await self.webhook_service.handle_transfer(event_data)
    
    # Delegate API methods
    async def get_subscriber_info(self, user_id: str) -> Dict[str, Any]:
        """Get subscriber information from RevenueCat API"""
        return await self.api_service.get_subscriber_info(user_id)
    
    # Delegate subscription methods
    async def _update_subscription(
        self,
        user_id: str,
        status: str,
        product_id: str,
        entitlement_id: str,
        expires_at: str = None
    ) -> None:
        """Update subscription (private method for backward compatibility)"""
        return await self.subscription_service.update_subscription(
            user_id, status, product_id, entitlement_id, expires_at
        )
    
    async def is_admin_user(self, user_id: str) -> bool:
        """Check if user is an admin user"""
        return await self.subscription_service.is_admin_user(user_id)
    
    async def _should_protect_from_downgrade(self, user_id: str) -> bool:
        """Check if user should be protected from downgrade (private method)"""
        return await self.subscription_service._should_protect_from_downgrade(user_id)
    
    async def _update_user_role(self, user_id: str, role, allow_downgrade: bool = True) -> None:
        """Update user role (private method for backward compatibility)"""
        return await self.subscription_service.update_user_role(user_id, role, allow_downgrade)

