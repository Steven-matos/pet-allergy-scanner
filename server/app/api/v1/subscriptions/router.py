"""
Subscription management API endpoints
"""

from fastapi import APIRouter, Depends, HTTPException, status, Request, Header
from supabase import Client
from typing import Optional
import logging

from app.api.v1.dependencies import get_current_user, get_supabase_client
from app.models.user import User
from app.models.subscription import (
    AppStoreReceiptVerification,
    AppStoreServerNotification,
    SubscriptionResponse
)
from app.services.subscription_service import SubscriptionService
from app.services.revenuecat_service import RevenueCatService
from app.services.subscription_checker import SubscriptionChecker

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/verify", response_model=dict, status_code=status.HTTP_200_OK)
async def verify_subscription(
    receipt: AppStoreReceiptVerification,
    current_user: User = Depends(get_current_user),
    supabase: Client = Depends(get_supabase_client)
):
    """
    Verify App Store receipt and activate/update subscription
    
    This endpoint should be called after a successful purchase in the iOS app.
    It verifies the receipt with Apple's servers and updates the user's subscription status.
    
    Args:
        receipt: Receipt verification data from iOS app
        current_user: Authenticated user
        supabase: Supabase client
        
    Returns:
        Verification result with subscription details
    """
    try:
        # Initialize subscription service
        subscription_service = SubscriptionService(
            supabase=supabase,
            shared_secret=receipt.password  # App-specific shared secret
        )
        
        # Verify receipt and update subscription
        result = await subscription_service.verify_receipt(
            receipt_data=receipt.receipt_data,
            user_id=current_user.id,
            is_sandbox=False  # Start with production, will fallback to sandbox if needed
        )
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error verifying subscription: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to verify subscription"
        )


@router.get("/status", response_model=dict, status_code=status.HTTP_200_OK)
async def get_subscription_status(
    current_user: User = Depends(get_current_user),
    supabase: Client = Depends(get_supabase_client)
):
    """
    Get current user's subscription status
    
    Uses RevenueCat as the source of truth for subscription status.
    Also checks for admin/protected users who have full access without subscription.
    
    Args:
        current_user: Authenticated user
        supabase: Supabase client
        
    Returns:
        Subscription status and details:
        {
            "has_subscription": bool,
            "is_premium": bool,
            "is_admin": bool,
            "subscription": Optional[Dict],
            "user_role": str
        }
    """
    try:
        # Use centralized subscription checker (RevenueCat as source of truth)
        checker = SubscriptionChecker(supabase)
        status_result = await checker.check_subscription_status(current_user.id)
        
        return {
            "has_subscription": status_result["has_active_subscription"],
            "is_premium": status_result["is_premium"],
            "is_admin": status_result["is_admin"],
            "subscription": status_result.get("subscription"),
            "user_role": status_result["user_role"],
            "source": status_result.get("source", "unknown")
        }
            
    except Exception as e:
        logger.error(f"Error fetching subscription status: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch subscription status"
        )


@router.post("/restore", response_model=dict, status_code=status.HTTP_200_OK)
async def restore_purchases(
    receipt: AppStoreReceiptVerification,
    current_user: User = Depends(get_current_user),
    supabase: Client = Depends(get_supabase_client)
):
    """
    Restore user's purchases from App Store receipt
    
    This is called when the user taps "Restore Purchases" in the app.
    It verifies the receipt and restores any active subscriptions.
    
    Args:
        receipt: Receipt data from iOS app
        current_user: Authenticated user
        supabase: Supabase client
        
    Returns:
        Restore result with subscription details
    """
    try:
        subscription_service = SubscriptionService(
            supabase=supabase,
            shared_secret=receipt.password
        )
        
        result = await subscription_service.verify_receipt(
            receipt_data=receipt.receipt_data,
            user_id=current_user.id,
            is_sandbox=False
        )
        
        return {
            "success": True,
            "message": "Purchases restored successfully",
            **result
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error restoring purchases: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to restore purchases"
        )


@router.post("/webhook", status_code=status.HTTP_200_OK, include_in_schema=False)
async def app_store_webhook(
    request: Request,
    supabase: Client = Depends(get_supabase_client)
):
    """
    Handle App Store Server Notifications (webhooks)
    
    Apple sends notifications for subscription events like:
    - Renewals
    - Cancellations
    - Billing issues
    - Refunds
    
    This endpoint processes these notifications and updates subscription status.
    
    Note: This endpoint should be configured in App Store Connect under
    "App Store Server Notifications" with your webhook URL.
    
    Args:
        request: Raw request with signed payload from Apple
        supabase: Supabase client
        
    Returns:
        Success response
    """
    try:
        # Get the signed payload from Apple
        body = await request.json()
        
        # TODO: Verify the signature using Apple's JWS verification
        # This is critical for security - only accept notifications from Apple
        # Reference: https://developer.apple.com/documentation/appstoreservernotifications/jwstransaction
        
        notification_type = body.get("notificationType")
        subtype = body.get("subtype")
        
        
        # Extract transaction data
        signed_transaction_info = body.get("data", {}).get("signedTransactionInfo")
        
        if not signed_transaction_info:
            logger.warning("No transaction info in webhook")
            return {"status": "ok"}
        
        # TODO: Decode and verify the JWT transaction info
        # TODO: Update subscription status based on notification type
        
        # Handle different notification types
        if notification_type == "DID_RENEW":
            # Update subscription with new expiration date
        elif notification_type == "DID_CHANGE_RENEWAL_STATUS":
            # Update auto-renew status
        elif notification_type == "EXPIRED":
            # Mark subscription as expired, downgrade user
        elif notification_type == "GRACE_PERIOD_EXPIRED":
            # Downgrade user after grace period
        elif notification_type == "REFUND":
            # Revoke subscription immediately
        
        return {"status": "ok"}
        
    except Exception as e:
        logger.error(f"Error processing App Store webhook: {str(e)}")
        # Return 200 anyway to prevent Apple from retrying
        return {"status": "error", "message": str(e)}

