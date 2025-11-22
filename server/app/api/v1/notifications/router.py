"""
Push notification router for handling APNs integration
Handles device token registration, notification sending, and management
"""

from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import Dict, Any, Optional
import json
import asyncio
from datetime import datetime, timedelta
from pydantic import BaseModel

from app.database import get_db
from app.models.user import UserResponse
from app.core.security.jwt_handler import get_current_user, security
from app.utils.logging_config import get_logger
from app.services.push_notification_service import PushNotificationService

logger = get_logger(__name__)

router = APIRouter(prefix="/notifications", tags=["notifications"])
security = HTTPBearer()

# Initialize push notification service
try:
    push_service = PushNotificationService()
except Exception as e:
    logger.warning(f"Failed to initialize PushNotificationService: {e}")
    logger.warning("Push notifications will not be available until configuration is fixed")
    push_service = None


class DeviceTokenRequest(BaseModel):
    """Request model for device token registration"""
    device_token: str


class SendNotificationRequest(BaseModel):
    """Request model for sending push notifications"""
    device_token: str
    payload: Dict[str, Any]
    
    class Config:
        """Pydantic configuration"""
        json_schema_extra = {
            "example": {
                "device_token": "abc123...",
                "payload": {
                    "aps": {
                        "alert": {
                            "title": "Test",
                            "body": "Test notification"
                        },
                        "sound": "default",
                        "badge": 1
                    }
                }
            }
        }


@router.post("/register-device")
async def register_device_token(
    request: DeviceTokenRequest,
    current_user: UserResponse = Depends(get_current_user),
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """
    Register device token for push notifications (authenticated)
    
    Args:
        request: DeviceTokenRequest containing device_token
        current_user: Current authenticated user
        credentials: JWT credentials for authenticated Supabase client
        
    Returns:
        Success message
    """
    try:
        # Extract device token from request
        device_token = request.device_token
        
        # Create authenticated Supabase client for RLS policies
        from app.core.config import settings
        from supabase import create_client
        
        supabase = create_client(
            settings.supabase_url,
            settings.supabase_key
        )
        supabase.auth.set_session(credentials.credentials, "")
        
        # Update user's device token
        # Note: Supabase UPDATE may return empty data array even on success
        # We'll verify success by checking if the update didn't raise an error
        response = supabase.table("users").update({
            "device_token": device_token,
            "updated_at": datetime.utcnow().isoformat()
        }).eq("id", current_user.id).execute()
        
        # Verify update succeeded by checking for errors
        if hasattr(response, 'error') and response.error:
            logger.error(f"Supabase error updating device token: {response.error}")
            raise HTTPException(status_code=500, detail="Failed to update device token")
        
        # If response.data is empty, it might still be successful (Supabase quirk)
        # But if we got here without an error, assume success
        return {"message": "Device token registered successfully"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to register device token: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to register device token: {str(e)}")


@router.post("/register-device-anonymous")
async def register_device_token_anonymous(
    request: DeviceTokenRequest,
    supabase = Depends(get_db)
):
    """
    Register device token for push notifications (anonymous)
    This endpoint allows device registration before user authentication
    Stores token temporarily until user authenticates
    
    Args:
        request: DeviceTokenRequest containing device_token
        supabase: Supabase client
        
    Returns:
        Success message with temporary token
    """
    try:
        # Extract device token from request
        device_token = request.device_token
        
        # Store device token in a temporary table with expiration
        # Token will be linked to user after authentication
        expires_at = (datetime.utcnow() + timedelta(days=30)).isoformat()
        
        try:
            # Try to insert into device_tokens_temp table
            # If table doesn't exist, we'll store in a simpler way
            response = supabase.table("device_tokens_temp").insert({
                "device_token": device_token,
                "created_at": datetime.utcnow().isoformat(),
                "expires_at": expires_at,
                "user_id": None  # Will be linked after authentication
            }).execute()
            
            logger.info(f"Anonymous device token registered and stored: {device_token[:20]}...")
        except Exception as table_error:
            # Table might not exist - log and continue
            # Token will be registered again after authentication
            logger.warning(f"Could not store anonymous device token in table: {table_error}")
            logger.info(f"Anonymous device token registration (not stored): {device_token[:20]}...")
        
        return {
            "message": "Device token registered successfully. Please complete authentication to enable notifications.",
            "requires_auth": True
        }
    except Exception as e:
        logger.error(f"Failed to register anonymous device token: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to register device token: {str(e)}")


@router.post("/send")
async def send_push_notification(
    request: SendNotificationRequest,
    current_user: UserResponse = Depends(get_current_user),
    background_tasks: BackgroundTasks = Depends()
):
    """
    Send push notification to device
    
    Args:
        request: SendNotificationRequest containing device_token and payload
        current_user: Current authenticated user
        background_tasks: Background tasks handler
        
    Returns:
        Success message
    """
    try:
        # Log request details for debugging
        logger.info(f"Received push notification request - device_token: {request.device_token[:20] if request.device_token else 'None'}..., payload keys: {list(request.payload.keys()) if request.payload else 'None'}")
        # Validate request fields
        if not request.device_token:
            raise HTTPException(status_code=400, detail="device_token is required")
        
        if not request.payload:
            raise HTTPException(status_code=400, detail="payload is required")
        
        if not isinstance(request.payload, dict):
            raise HTTPException(status_code=400, detail="payload must be a dictionary")
        
        device_token = request.device_token
        payload = request.payload
        
        logger.info(f"Sending push notification to device {device_token[:20]}...")
        logger.debug(f"Payload: {json.dumps(payload, default=str)}")
        
        # Extract delay if specified in payload - convert to int
        delay = 0
        if "delay" in payload:
            try:
                delay = int(payload.get("delay", 0))
                # Remove delay from payload as it's not part of APNs payload
                payload = {k: v for k, v in payload.items() if k != "delay"}
            except (ValueError, TypeError) as e:
                logger.warning(f"Invalid delay value: {payload.get('delay')}, using 0. Error: {e}")
                delay = 0
        
        if push_service is None:
            raise HTTPException(status_code=503, detail="Push notification service is not configured")
        
        if delay > 0:
            # Schedule notification for later
            background_tasks.add_task(
                send_delayed_notification,
                device_token,
                payload,
                delay
            )
            logger.info(f"Notification scheduled for {delay} seconds")
            return {"message": "Notification scheduled successfully"}
        else:
            # Send immediately
            success = await push_service.send_notification(device_token, payload)
            if success:
                logger.info(f"Notification sent successfully to {device_token[:20]}...")
                return {"message": "Notification sent successfully"}
            else:
                logger.error(f"Failed to send notification to {device_token[:20]}...")
                raise HTTPException(status_code=500, detail="Failed to send notification to APNs")
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to send notification: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to send notification: {str(e)}")


@router.post("/cancel-all")
async def cancel_all_notifications(
    current_user: UserResponse = Depends(get_current_user),
    supabase = Depends(get_db)
):
    """
    Cancel all pending notifications for the current user
    
    Args:
        current_user: Current authenticated user
        supabase: Supabase client
        
    Returns:
        Success message
    """
    try:
        if push_service is None:
            raise HTTPException(status_code=503, detail="Push notification service is not configured")
        
        # Cancel all scheduled notifications for this user
        await push_service.cancel_user_notifications(current_user.id)
        
        return {"message": "All notifications cancelled successfully"}
    except Exception as e:
        logger.error(f"Failed to cancel notifications: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to cancel notifications: {str(e)}")


@router.post("/schedule-engagement")
async def schedule_engagement_notifications(
    current_user: UserResponse = Depends(get_current_user),
    background_tasks: BackgroundTasks = Depends()
):
    """
    Schedule engagement reminder notifications
    
    Args:
        current_user: Current authenticated user
        background_tasks: Background tasks handler
        
    Returns:
        Success message
    """
    try:
        if not current_user.device_token:
            raise HTTPException(status_code=400, detail="No device token registered")
        
        # Schedule weekly reminder (7 days)
        weekly_payload = {
            "aps": {
                "alert": {
                    "title": "🔍 Time for a Scan!",
                    "body": "Keep your pet safe by scanning their food ingredients regularly."
                },
                "sound": "default",
                "badge": 1,
                "category": "engagement"
            },
            "type": "weekly_reminder",
            "action": "navigate_to_scan"
        }
        
        # Schedule monthly reminder (30 days)
        monthly_payload = {
            "aps": {
                "alert": {
                    "title": "🐾 We Miss You!",
                    "body": "It's been a while since your last scan. Your pet's health is important to us."
                },
                "sound": "default",
                "badge": 1,
                "category": "engagement"
            },
            "type": "monthly_reminder",
            "action": "navigate_to_scan"
        }
        
        # Schedule notifications
        background_tasks.add_task(
            send_delayed_notification,
            current_user.device_token,
            weekly_payload,
            7 * 24 * 60 * 60  # 7 days in seconds
        )
        
        background_tasks.add_task(
            send_delayed_notification,
            current_user.device_token,
            monthly_payload,
            30 * 24 * 60 * 60  # 30 days in seconds
        )
        
        return {"message": "Engagement notifications scheduled successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to schedule notifications: {str(e)}")


@router.post("/send-birthday")
async def send_birthday_notification(
    pet_name: str,
    pet_id: str,
    current_user: UserResponse = Depends(get_current_user),
    background_tasks: BackgroundTasks = Depends()
):
    """
    Send birthday celebration notification
    
    Args:
        pet_name: Name of the pet
        pet_id: ID of the pet
        current_user: Current authenticated user
        background_tasks: Background tasks handler
        
    Returns:
        Success message
    """
    try:
        if not current_user.device_token:
            raise HTTPException(status_code=400, detail="No device token registered")
        
        birthday_payload = {
            "aps": {
                "alert": {
                    "title": f"🎉 Surprise! It's {pet_name}'s Birthday Month! 🎂",
                    "body": f"This month is {pet_name}'s special time! Time to celebrate! 🐾✨"
                },
                "sound": "default",
                "badge": 1,
                "category": "birthday"
            },
            "type": "birthday_celebration",
            "pet_id": pet_id,
            "action": "show_birthday_celebration"
        }
        
        if push_service is None:
            raise HTTPException(status_code=503, detail="Push notification service is not configured")
        
        # Send immediately
        await push_service.send_notification(current_user.device_token, birthday_payload)
        
        return {"message": "Birthday notification sent successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to send birthday notification: {str(e)}")


async def send_delayed_notification(device_token: str, payload: Dict[str, Any], delay: int):
    """
    Send notification after specified delay
    
    Args:
        device_token: Target device token
        payload: Notification payload
        delay: Delay in seconds (integer)
    """
    # Remove delay from payload before sending (it's not part of APNs payload)
    payload_without_delay = {k: v for k, v in payload.items() if k != "delay"}
    
    await asyncio.sleep(delay)
    try:
        if push_service is None:
            logger.error("Push notification service is not configured - cannot send delayed notification")
            return
        
        await push_service.send_notification(device_token, payload_without_delay)
        logger.info(f"Delayed notification sent successfully to {device_token[:20]}...")
    except Exception as e:
        logger.error(f"Failed to send delayed notification to {device_token[:20]}...: {e}")
