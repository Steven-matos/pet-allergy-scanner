"""
RevenueCat webhook handler for subscription events

This replaces direct App Store receipt verification with RevenueCat's webhook system.
RevenueCat handles receipt validation, server notifications, and provides a unified API
for subscription management across iOS and Android.

Documentation: https://www.revenuecat.com/docs/webhooks
"""

from fastapi import APIRouter, Depends, HTTPException, status, Request, Header
from supabase import Client
from typing import Optional
import logging
import hmac
import hashlib

from app.api.v1.dependencies import get_supabase_client
from app.services.revenuecat_service import RevenueCatService
from app.core.config import settings

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/webhook", status_code=status.HTTP_200_OK, include_in_schema=False)
async def revenuecat_webhook(
    request: Request,
    supabase: Client = Depends(get_supabase_client),
    x_revenuecat_signature: Optional[str] = Header(None),
    authorization: Optional[str] = Header(None)
):
    """
    Handle RevenueCat webhook events
    
    RevenueCat sends notifications for:
    - Initial purchases
    - Subscription renewals
    - Cancellations
    - Billing issues
    - Refunds
    - Trial conversions
    - And more...
    
    This endpoint processes these events and updates user subscription status.
    
    Setup:
    1. Configure webhook URL in RevenueCat dashboard: https://app.revenuecat.com
    2. Set webhook authorization header in dashboard settings
    3. Add REVENUECAT_WEBHOOK_SECRET to your environment variables
    
    Args:
        request: Raw request with webhook payload from RevenueCat
        supabase: Supabase client
        x_revenuecat_signature: Signature header for webhook verification
        
    Returns:
        Success response
    """
    try:
        # Get the raw body for signature verification
        body = await request.body()
        body_str = body.decode('utf-8')
        
        # Verify webhook signature (CRITICAL for security)
        if not _verify_webhook_signature(body_str, x_revenuecat_signature, authorization):
            logger.warning("Invalid RevenueCat webhook signature")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid webhook signature"
            )
        
        # Parse the webhook payload
        payload = await request.json()
        
        # RevenueCat webhook structure: payload contains "event" object with event data
        # The event type can be in payload.type or event.type
        event_data = payload.get("event", payload)  # Fallback to payload if no event key
        event_type = payload.get("type") or event_data.get("type")
        
        if not event_type:
            logger.error("No event type found in webhook payload")
            logger.debug(f"Webhook payload structure: {payload}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Missing event type in webhook payload"
            )
        
        user_id = event_data.get("app_user_id") or payload.get("app_user_id")
        if not user_id:
            logger.error(f"No app_user_id found in webhook payload for event {event_type}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Missing app_user_id in webhook payload"
            )
        
        logger.info(f"Processing RevenueCat webhook: event_type={event_type}, user_id={user_id}")
        
        # Initialize RevenueCat service
        revenuecat_service = RevenueCatService(supabase)
        
        # Process the event based on type
        try:
            if event_type == "INITIAL_PURCHASE":
                await revenuecat_service.handle_initial_purchase(event_data)
                logger.info(f"✅ Successfully processed INITIAL_PURCHASE for user {user_id}")
                
            elif event_type == "RENEWAL":
                await revenuecat_service.handle_renewal(event_data)
                logger.info(f"✅ Successfully processed RENEWAL for user {user_id}")
                
            elif event_type == "CANCELLATION":
                await revenuecat_service.handle_cancellation(event_data)
                logger.info(f"✅ Successfully processed CANCELLATION for user {user_id}")
                
            elif event_type == "UNCANCELLATION":
                await revenuecat_service.handle_uncancellation(event_data)
                logger.info(f"✅ Successfully processed UNCANCELLATION for user {user_id}")
                
            elif event_type == "NON_RENEWING_PURCHASE":
                await revenuecat_service.handle_non_renewing_purchase(event_data)
                logger.info(f"✅ Successfully processed NON_RENEWING_PURCHASE for user {user_id}")
                
            elif event_type == "EXPIRATION":
                await revenuecat_service.handle_expiration(event_data)
                logger.info(f"✅ Successfully processed EXPIRATION for user {user_id}")
                
            elif event_type == "BILLING_ISSUE":
                await revenuecat_service.handle_billing_issue(event_data)
                logger.info(f"✅ Successfully processed BILLING_ISSUE for user {user_id}")
                
            elif event_type == "SUBSCRIBER_ALIAS":
                await revenuecat_service.handle_subscriber_alias(event_data)
                logger.info(f"✅ Successfully processed SUBSCRIBER_ALIAS for user {user_id}")
                
            elif event_type == "SUBSCRIPTION_PAUSED":
                await revenuecat_service.handle_subscription_paused(event_data)
                logger.info(f"✅ Successfully processed SUBSCRIPTION_PAUSED for user {user_id}")
                
            elif event_type == "TRANSFER":
                await revenuecat_service.handle_transfer(event_data)
                logger.info(f"✅ Successfully processed TRANSFER for user {user_id}")
                
            else:
                logger.warning(f"⚠️ Unhandled RevenueCat event type: {event_type} for user {user_id}")
                # Still return success to prevent RevenueCat from retrying
                return {"status": "success", "message": f"Unhandled event type: {event_type}"}
            
            # Verify the update was successful by checking user role
            try:
                from app.shared.utils.async_supabase import execute_async
                user_response = await execute_async(
                    lambda: supabase.table("users").select("role").eq("id", user_id).execute()
                )
                if user_response.data:
                    updated_role = user_response.data[0].get("role")
                    logger.info(f"✅ Verified backend update: user {user_id} role is now {updated_role}")
                else:
                    logger.warning(f"⚠️ Could not verify user role update for user {user_id}")
            except Exception as verify_error:
                logger.warning(f"⚠️ Error verifying backend update: {str(verify_error)}")
            
        except Exception as handler_error:
            logger.error(f"❌ Error processing {event_type} for user {user_id}: {str(handler_error)}", exc_info=True)
            # Re-raise to return error status to RevenueCat (they will retry)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to process webhook event: {str(handler_error)}"
            )
        
        return {"status": "success", "event_type": event_type, "user_id": user_id}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error processing RevenueCat webhook: {str(e)}", exc_info=True)
        # Return 200 to prevent RevenueCat from retrying
        return {"status": "error", "message": str(e)}


def _verify_webhook_signature(
    body: str,
    signature: Optional[str],
    authorization_header: Optional[str]
) -> bool:
    """
    Verify RevenueCat webhook signature or shared secret
    
    Args:
        body: Raw request body as string
        signature: Signature from X-RevenueCat-Signature header
        authorization_header: Optional Authorization header containing shared secret
        
    Returns:
        True if signature is valid
    """
    # Get webhook secret from environment
    webhook_secret = settings.revenuecat_webhook_secret
    
    if not webhook_secret:
        logger.error("REVENUECAT_WEBHOOK_SECRET not configured")
        return False
    
    # Prefer HMAC signature if provided (X-RevenueCat-Signature)
    if signature:
        expected_signature = hmac.new(
            webhook_secret.encode('utf-8'),
            body.encode('utf-8'),
            hashlib.sha256
        ).hexdigest()
        return hmac.compare_digest(signature, expected_signature)
    
    # Fall back to Authorization header shared-secret comparison
    if authorization_header:
        return hmac.compare_digest(authorization_header.strip(), webhook_secret.strip())
    
    logger.warning("No signature or authorization header provided in webhook request")
    return False


@router.get("/subscription-info/{user_id}", status_code=status.HTTP_200_OK)
async def get_subscription_info(
    user_id: str,
    supabase: Client = Depends(get_supabase_client)
):
    """
    Get user's subscription information from RevenueCat
    
    This endpoint can be used to fetch real-time subscription status
    directly from RevenueCat's API (optional - webhooks are preferred).
    
    Args:
        user_id: User ID (app_user_id in RevenueCat)
        supabase: Supabase client
        
    Returns:
        Subscription information
    """
    try:
        revenuecat_service = RevenueCatService(supabase)
        subscription_info = await revenuecat_service.get_subscriber_info(user_id)
        
        return {
            "success": True,
            "subscription": subscription_info
        }
        
    except Exception as e:
        logger.error(f"Error fetching subscription info: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch subscription information"
        )

