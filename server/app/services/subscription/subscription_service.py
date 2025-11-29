"""
Subscription management service for App Store subscriptions
"""

import httpx
import json
import base64
from datetime import datetime, timezone
from app.shared.services.datetime_service import DateTimeService
from app.shared.services.database_operation_service import DatabaseOperationService
from typing import Optional, Dict, Any
from fastapi import HTTPException, status
from supabase import Client
import logging

from app.models.core.subscription import (
    SubscriptionCreate,
    SubscriptionUpdate,
    SubscriptionStatus,
    SubscriptionTier,
    SubscriptionResponse
)
from app.models.core.user import UserRole

logger = logging.getLogger(__name__)


class SubscriptionService:
    """Service for managing App Store subscriptions"""
    
    # App Store verification URLs
    PRODUCTION_URL = "https://buy.itunes.apple.com/verifyReceipt"
    SANDBOX_URL = "https://sandbox.itunes.apple.com/verifyReceipt"
    
    def __init__(self, supabase: Client, shared_secret: Optional[str] = None):
        """
        Initialize subscription service
        
        Args:
            supabase: Supabase client instance
            shared_secret: App-specific shared secret from App Store Connect
        """
        self.supabase = supabase
        self.shared_secret = shared_secret
    
    async def verify_receipt(
        self,
        receipt_data: str,
        user_id: str,
        is_sandbox: bool = False
    ) -> Dict[str, Any]:
        """
        Verify App Store receipt and update subscription status
        
        Args:
            receipt_data: Base64 encoded receipt data
            user_id: User ID to associate subscription with
            is_sandbox: Whether to use sandbox environment
            
        Returns:
            Verification result with subscription info
            
        Raises:
            HTTPException: If verification fails
        """
        # Prepare verification request
        verification_url = self.SANDBOX_URL if is_sandbox else self.PRODUCTION_URL
        
        request_body = {
            "receipt-data": receipt_data,
            "exclude-old-transactions": True
        }
        
        if self.shared_secret:
            request_body["password"] = self.shared_secret
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    verification_url,
                    json=request_body,
                    timeout=30.0
                )
                result = response.json()
                
                # Handle sandbox/production environment switching
                if result.get("status") == 21007 and not is_sandbox:
                    # Receipt is from sandbox, retry with sandbox URL
                    return await self.verify_receipt(receipt_data, user_id, is_sandbox=True)
                
                # Check verification status
                if result.get("status") != 0:
                    logger.error(f"Receipt verification failed: {result.get('status')}")
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=f"Receipt verification failed with status: {result.get('status')}"
                    )
                
                # Extract subscription info
                receipt = result.get("receipt", {})
                latest_receipt_info = result.get("latest_receipt_info", [])
                pending_renewal_info = result.get("pending_renewal_info", [])
                
                if not latest_receipt_info:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="No subscription information found in receipt"
                    )
                
                # Get the most recent transaction
                latest_transaction = latest_receipt_info[-1]
                
                # Create or update subscription
                subscription_data = await self._process_transaction(
                    latest_transaction,
                    pending_renewal_info,
                    user_id
                )
                
                # Update user role based on subscription status
                await self._update_user_role(user_id, subscription_data["status"])
                
                return {
                    "success": True,
                    "subscription": subscription_data,
                    "environment": "sandbox" if is_sandbox else "production"
                }
                
        except httpx.HTTPError as e:
            logger.error(f"HTTP error during receipt verification: {str(e)}")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Unable to verify receipt with App Store"
            )
        except Exception as e:
            logger.error(f"Error verifying receipt: {str(e)}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to verify subscription"
            )
    
    async def _process_transaction(
        self,
        transaction: Dict[str, Any],
        renewal_info: list,
        user_id: str
    ) -> Dict[str, Any]:
        """
        Process transaction data and create/update subscription
        
        Args:
            transaction: Transaction data from App Store
            renewal_info: Pending renewal information
            user_id: User ID
            
        Returns:
            Subscription data
        """
        product_id = transaction.get("product_id")
        original_transaction_id = transaction.get("original_transaction_id")
        transaction_id = transaction.get("transaction_id")
        purchase_date_ms = int(transaction.get("purchase_date_ms", 0))
        expires_date_ms = int(transaction.get("expires_date_ms", 0))
        
        # Determine subscription tier
        tier = self._get_subscription_tier(product_id)
        
        # Determine subscription status
        current_time = DateTimeService.now()
        expiration_date = datetime.fromtimestamp(expires_date_ms / 1000, timezone.utc)
        
        if current_time < expiration_date:
            subscription_status = SubscriptionStatus.ACTIVE
        else:
            subscription_status = SubscriptionStatus.EXPIRED
        
        # Check auto-renew status
        auto_renew = True
        if renewal_info:
            renewal = renewal_info[0]
            auto_renew = renewal.get("auto_renew_status") == "1"
            
            # Check if in grace period
            grace_period_expires_date = renewal.get("grace_period_expires_date_ms")
            if grace_period_expires_date:
                grace_expiry = datetime.fromtimestamp(
                    int(grace_period_expires_date) / 1000,
                    timezone.utc
                )
                if current_time < grace_expiry:
                    subscription_status = SubscriptionStatus.GRACE_PERIOD
        
        # Create or update subscription in database
        subscription_data = {
            "user_id": user_id,
            "product_id": product_id,
            "tier": tier,
            "status": subscription_status,
            "purchase_date": datetime.fromtimestamp(purchase_date_ms / 1000, timezone.utc).isoformat(),
            "expiration_date": expiration_date.isoformat(),
            "auto_renew": auto_renew,
            "original_transaction_id": original_transaction_id,
            "latest_transaction_id": transaction_id
        }
        
        # Check if subscription exists
        existing = self.supabase.table("subscriptions").select("*").eq(
            "original_transaction_id", original_transaction_id
        ).execute()
        
        db_service = DatabaseOperationService(self.supabase)
        
        if existing.data:
            # Update existing subscription using centralized service
            existing_sub = existing.data[0]
            update_data = {
                "status": subscription_status,
                "expiration_date": expiration_date.isoformat(),
                "auto_renew": auto_renew,
                "latest_transaction_id": transaction_id
            }
            # Use original_transaction_id as the ID column for update
            result = await db_service.update_with_timestamp(
                "subscriptions",
                existing_sub.get("id"),
                update_data
            )
        else:
            # Create new subscription using centralized service
            result = await db_service.insert_with_timestamps("subscriptions", subscription_data)
        
        return subscription_data
    
    def _get_subscription_tier(self, product_id: str) -> str:
        """
        Determine subscription tier from product ID
        
        Args:
            product_id: App Store product ID
            
        Returns:
            Subscription tier
        """
        if "weekly" in product_id.lower():
            return SubscriptionTier.WEEKLY
        elif "monthly" in product_id.lower():
            return SubscriptionTier.MONTHLY
        elif "yearly" in product_id.lower() or "annual" in product_id.lower():
            return SubscriptionTier.YEARLY
        return SubscriptionTier.MONTHLY  # Default fallback
    
    async def _update_user_role(self, user_id: str, subscription_status: str) -> None:
        """
        Update user role based on subscription status
        
        Args:
            user_id: User ID
            subscription_status: Current subscription status
        """
        from app.shared.services.user_role_manager import UserRoleManager
        
        # Determine role based on subscription status
        if subscription_status in [
            SubscriptionStatus.ACTIVE,
            SubscriptionStatus.GRACE_PERIOD,
            SubscriptionStatus.BILLING_RETRY
        ]:
            new_role = UserRole.PREMIUM
        else:
            new_role = UserRole.FREE
        
        # Use centralized role manager (ensures bypass flag is checked)
        role_manager = UserRoleManager(self.supabase)
        reason = f"Subscription status change: {subscription_status}"
        await role_manager.update_user_role(user_id, new_role, reason)
    
    async def get_user_subscription(self, user_id: str) -> Optional[Dict[str, Any]]:
        """
        Get active subscription for a user
        
        Args:
            user_id: User ID
            
        Returns:
            Subscription data or None
        """
        try:
            result = self.supabase.table("subscriptions").select("*").eq(
                "user_id", user_id
            ).eq("status", SubscriptionStatus.ACTIVE).execute()
            
            if result.data:
                return result.data[0]
            return None
        except Exception as e:
            logger.error(f"Error fetching user subscription: {str(e)}")
            return None
    
    async def cancel_subscription(self, user_id: str, original_transaction_id: str) -> bool:
        """
        Mark subscription as cancelled (user cancelled auto-renew)
        
        Args:
            user_id: User ID
            original_transaction_id: Original transaction ID
            
        Returns:
            True if successful
        """
        try:
            # Use DatabaseOperationService for update
            # First get subscription ID
            sub_response = self.supabase.table("subscriptions").select("id").eq("user_id", user_id).eq(
                "original_transaction_id", original_transaction_id
            ).limit(1).execute()
            
            if not sub_response.data:
                return False
            
            db_service = DatabaseOperationService(self.supabase)
            await db_service.update_with_timestamp(
                "subscriptions",
                sub_response.data[0]["id"],
                {"auto_renew": False}
            )
            
            return True
        except Exception as e:
            logger.error(f"Error cancelling subscription: {str(e)}")
            return False

