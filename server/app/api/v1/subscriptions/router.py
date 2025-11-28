"""
Subscription management API endpoints
"""

from fastapi import APIRouter, Depends, HTTPException, status, Request, Header
from supabase import Client
from typing import Optional
import logging

from app.api.v1.dependencies import get_current_user, get_supabase_client
from app.models.user import User, UserRole
from app.models.subscription import (
    AppStoreReceiptVerification,
    AppStoreServerNotification,
    SubscriptionResponse
)
from app.services.subscription_service import SubscriptionService
from app.services.revenuecat_service import RevenueCatService
from app.services.subscription_checker import SubscriptionChecker
from app.core.config import settings
from pydantic import BaseModel

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
        from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=UserFriendlyErrorMessages.get_user_friendly_message("failed to verify subscription", context="subscription", action="verify")
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
        
        # Get bypass_subscription flag from user record
        from app.shared.utils.async_supabase import execute_async
        user_response = await execute_async(
            lambda: supabase.table("users").select("bypass_subscription").eq("id", current_user.id).execute()
        )
        bypass_subscription = False
        if user_response.data:
            bypass_subscription = user_response.data[0].get("bypass_subscription", False)
        
        return {
            "has_subscription": status_result["has_active_subscription"],
            "is_premium": status_result["is_premium"],
            "is_admin": status_result["is_admin"],
            "bypass_subscription": bypass_subscription,
            "subscription": status_result.get("subscription"),
            "user_role": status_result["user_role"],
            "source": status_result.get("source", "unknown")
        }
            
    except Exception as e:
        logger.error(f"Error fetching subscription status: {str(e)}")
        from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=UserFriendlyErrorMessages.get_user_friendly_message("failed to fetch subscription status", context="subscription", action="status")
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
        from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=UserFriendlyErrorMessages.get_user_friendly_message("failed to restore purchases", context="subscription", action="restore")
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
        
        # Verify the signature using Apple's JWS verification
        # This is critical for security - only accept notifications from Apple
        # Reference: https://developer.apple.com/documentation/appstoreservernotifications/jwstransaction
        try:
            # Verify JWT signature from Apple
            # Apple uses ES256 algorithm with their public keys
            # For production, you should fetch Apple's public keys from:
            # https://api.appstoreconnect.apple.com/v1/certificates
            # For now, we'll decode without verification (development only)
            # TODO: Implement full JWT verification with Apple's public keys in production
            
            notification_type = body.get("notificationType")
            subtype = body.get("subtype")
            
            # Extract transaction data
            signed_transaction_info = body.get("data", {}).get("signedTransactionInfo")
            signed_renewal_info = body.get("data", {}).get("signedRenewalInfo")
            
            if not signed_transaction_info:
                logger.warning("No transaction info in webhook")
                return {"status": "ok"}
            
            # Decode and verify the JWT transaction info
            import jwt
            from jwt import PyJWKClient
            
            # Decode JWT without verification (for development)
            # In production, use Apple's public keys for verification
            try:
                # Decode JWT header to get key ID
                unverified_header = jwt.get_unverified_header(signed_transaction_info)
                key_id = unverified_header.get("kid")
                
                # Decode JWT payload (without verification for now)
                # In production, verify with Apple's public keys
                transaction_data = jwt.decode(
                    signed_transaction_info,
                    options={"verify_signature": False}  # Skip verification in development
                )
                
                logger.info(f"Decoded transaction JWT: transaction_id={transaction_data.get('transactionId')}")
                
                # Extract transaction details
                transaction_id = transaction_data.get("transactionId")
                original_transaction_id = transaction_data.get("originalTransactionId")
                product_id = transaction_data.get("productId")
                purchase_date = transaction_data.get("purchaseDate")
                expires_date = transaction_data.get("expiresDate")
                revocation_date = transaction_data.get("revocationDate")
                revocation_reason = transaction_data.get("revocationReason")
                
                # Get user ID from transaction (if stored in our system)
                # For App Store, we need to map transaction to user
                # This typically requires storing original_transaction_id when user purchases
                
                # Update subscription status based on notification type
                revenuecat_service = RevenueCatService(supabase)
                
                if notification_type == "DID_RENEW":
                    # Update subscription with new expiration date
                    if expires_date:
                        logger.info(f"Subscription renewed: transaction_id={transaction_id}, expires={expires_date}")
                        # Find user by original_transaction_id and update subscription
                        # This would require a lookup in subscriptions table
                
                elif notification_type == "DID_CHANGE_RENEWAL_STATUS":
                    # Update auto-renew status
                    if signed_renewal_info:
                        renewal_data = jwt.decode(
                            signed_renewal_info,
                            options={"verify_signature": False}
                        )
                        auto_renew_status = renewal_data.get("autoRenewStatus")
                        logger.info(f"Auto-renew status changed: {auto_renew_status}")
                
                elif notification_type == "EXPIRED":
                    # Mark subscription as expired, downgrade user
                    logger.info(f"Subscription expired: transaction_id={transaction_id}")
                    # Find user and update subscription status
                
                elif notification_type == "GRACE_PERIOD_EXPIRED":
                    # Downgrade user after grace period
                    logger.info(f"Grace period expired: transaction_id={transaction_id}")
                    # Find user and downgrade subscription
                
                elif notification_type == "REFUND":
                    # Revoke subscription immediately
                    logger.warning(f"Subscription refunded: transaction_id={transaction_id}, reason={revocation_reason}")
                    # Find user and revoke subscription immediately
                
                elif notification_type == "REVOKE":
                    # Subscription revoked
                    logger.warning(f"Subscription revoked: transaction_id={transaction_id}, reason={revocation_reason}")
                    # Find user and revoke subscription
                
            except jwt.InvalidTokenError as jwt_error:
                logger.error(f"Invalid JWT token in webhook: {str(jwt_error)}")
                return {"status": "error", "message": "Invalid JWT token"}
            
        except Exception as verification_error:
            logger.error(f"Error verifying JWT signature: {str(verification_error)}")
            # In production, reject invalid signatures
            # For development, log and continue
            if settings.environment == "production":
                return {"status": "error", "message": "Invalid signature"}
        
        return {"status": "ok"}
        
    except Exception as e:
        logger.error(f"Error processing App Store webhook: {str(e)}")
        # Return 200 anyway to prevent Apple from retrying
        return {"status": "error", "message": str(e)}


# Admin endpoint models
class BypassSubscriptionRequest(BaseModel):
    """Request model for setting bypass subscription flag"""
    user_id: str
    bypass: bool


@router.post("/admin/set-bypass", response_model=dict, status_code=status.HTTP_200_OK)
async def set_bypass_subscription(
    request: BypassSubscriptionRequest,
    current_user: User = Depends(get_current_user),
    supabase: Client = Depends(get_supabase_client)
):
    """
    Admin endpoint to set/unset bypass_subscription flag for a user
    
    This allows certain accounts to bypass subscription checks and have full premium access.
    Only users with bypass_subscription flag or protected emails can use this endpoint.
    
    Args:
        request: Request with user_id and bypass flag
        current_user: Authenticated user (must be admin)
        supabase: Supabase client
        
    Returns:
        Success message with updated user info
    """
    try:
        # Check if current user is admin (has bypass or is in protected emails)
        revenuecat_service = RevenueCatService(supabase)
        if not await revenuecat_service.is_admin_user(current_user.id):
            from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=UserFriendlyErrorMessages.get_user_friendly_message("only admin users can set bypass subscription flags")
            )
        
        # Update user's bypass_subscription flag using centralized services
        from app.shared.services.database_operation_service import DatabaseOperationService
        from app.shared.services.user_role_manager import UserRoleManager
        
        # Update bypass_subscription flag using DatabaseOperationService
        db_service = DatabaseOperationService(supabase)
        await db_service.update_with_timestamp(
            "users",
            request.user_id,
            {"bypass_subscription": request.bypass}
        )
        
        # Update role using centralized UserRoleManager
        role_manager = UserRoleManager(supabase)
        await role_manager.update_user_role(
                request.user_id, 
                UserRole.PREMIUM,
                "Bypass subscription enabled"
            )
        
        logger.info(f"Admin {current_user.id} set bypass_subscription={request.bypass} for user {request.user_id}")
        
        return {
            "success": True,
            "message": f"Bypass subscription {'enabled' if request.bypass else 'disabled'} for user {request.user_id}",
            "user_id": request.user_id,
            "bypass_subscription": request.bypass
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error setting bypass subscription: {str(e)}")
        from app.shared.services.user_friendly_error_messages import UserFriendlyErrorMessages
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=UserFriendlyErrorMessages.get_user_friendly_message("failed to set bypass subscription flag")
        )

