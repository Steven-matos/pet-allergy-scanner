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
from app.shared.services.datetime_service import DateTimeService
from pydantic import BaseModel

from app.database import get_db
from app.models.user import UserResponse
from app.core.security.jwt_handler import get_current_user, security
from app.api.v1.dependencies import get_authenticated_supabase_client
from app.utils.logging_config import get_logger
from supabase import Client
from app.services.push_notification_service import PushNotificationService

logger = get_logger(__name__)

router = APIRouter(prefix="/notifications", tags=["notifications"])
security = HTTPBearer()

# Maximum delay for notifications to prevent platform time_t overflow
# Set to 1 year (31536000 seconds) to stay well within platform limits
MAX_NOTIFICATION_DELAY_SECONDS = 31536000  # 365 * 24 * 60 * 60

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
    supabase: Client = Depends(get_authenticated_supabase_client)
):
    """
    Register device token for push notifications (authenticated)
    
    Args:
        request: DeviceTokenRequest containing device_token
        current_user: Current authenticated user
        supabase: Authenticated Supabase client
        
    Returns:
        Success message
    """
    try:
        # Extract device token from request
        device_token = request.device_token
        
        # Update user's device token using centralized service
        from app.shared.services.database_operation_service import DatabaseOperationService
        
        db_service = DatabaseOperationService(supabase)
        db_service.update_with_timestamp(
            "users",
            current_user.id,
            {"device_token": device_token}
        )
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
        expires_at = (DateTimeService.now() + timedelta(days=30)).isoformat()
        
        try:
            # Try to insert into device_tokens_temp table
            # If table doesn't exist, we'll store in a simpler way
            from app.shared.services.database_operation_service import DatabaseOperationService
            db_service = DatabaseOperationService(supabase)
            db_service.insert_with_timestamps("device_tokens_temp", {
                "device_token": device_token,
                "expires_at": expires_at,
                "user_id": None  # Will be linked after authentication
            })
            
        except Exception as table_error:
            # Table might not exist - log and continue
            # Token will be registered again after authentication
            logger.warning(f"Could not store anonymous device token in table: {table_error}")
        
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
    background_tasks: BackgroundTasks,
    current_user: UserResponse = Depends(get_current_user)
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
        # Validate request fields
        if not request.device_token:
            raise HTTPException(status_code=400, detail="device_token is required")
        
        if not request.payload:
            raise HTTPException(status_code=400, detail="payload is required")
        
        if not isinstance(request.payload, dict):
            raise HTTPException(status_code=400, detail="payload must be a dictionary")
        
        device_token = request.device_token
        payload = request.payload
        
        
        # Extract delay if specified in payload - convert to int
        delay = 0
        if "delay" in payload:
            try:
                delay = int(payload.get("delay", 0))
                # Validate delay is within reasonable bounds
                if delay < 0:
                    logger.warning(f"Negative delay value: {delay}, using 0")
                    delay = 0
                elif delay > MAX_NOTIFICATION_DELAY_SECONDS:
                    logger.warning(f"Delay value {delay} exceeds maximum {MAX_NOTIFICATION_DELAY_SECONDS}, capping to maximum")
                    delay = MAX_NOTIFICATION_DELAY_SECONDS
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
            return {"message": "Notification scheduled successfully"}
        else:
            # Send immediately
            success = await push_service.send_notification(device_token, payload)
            if success:
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
    background_tasks: BackgroundTasks,
    current_user: UserResponse = Depends(get_current_user)
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
        
        # Schedule notifications with validated delays
        # Calculate delays and ensure they're within bounds
        weekly_delay = 7 * 24 * 60 * 60  # 7 days in seconds (604800)
        monthly_delay = 30 * 24 * 60 * 60  # 30 days in seconds (2592000)
        
        # Validate delays are within bounds (they should be, but check anyway)
        if weekly_delay > MAX_NOTIFICATION_DELAY_SECONDS or weekly_delay < 0:
            logger.error(f"Invalid weekly delay: {weekly_delay}")
            weekly_delay = min(weekly_delay, MAX_NOTIFICATION_DELAY_SECONDS)
        
        if monthly_delay > MAX_NOTIFICATION_DELAY_SECONDS or monthly_delay < 0:
            logger.error(f"Invalid monthly delay: {monthly_delay}")
            monthly_delay = min(monthly_delay, MAX_NOTIFICATION_DELAY_SECONDS)
        
        background_tasks.add_task(
            send_delayed_notification,
            current_user.device_token,
            weekly_payload,
            weekly_delay
        )
        
        background_tasks.add_task(
            send_delayed_notification,
            current_user.device_token,
            monthly_payload,
            monthly_delay
        )
        
        return {"message": "Engagement notifications scheduled successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to schedule notifications: {str(e)}")


@router.post("/send-birthday")
async def send_birthday_notification(
    pet_name: str,
    pet_id: str,
    background_tasks: BackgroundTasks,
    current_user: UserResponse = Depends(get_current_user)
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
    # Validate and clamp delay to prevent overflow errors
    # This prevents OverflowError: timestamp out of range for platform time_t
    MIN_DELAY_SECONDS = 0
    
    if delay < MIN_DELAY_SECONDS:
        logger.warning(f"Invalid delay value {delay} seconds, using 0")
        delay = MIN_DELAY_SECONDS
    elif delay > MAX_NOTIFICATION_DELAY_SECONDS:
        logger.warning(f"Delay value {delay} seconds exceeds maximum {MAX_NOTIFICATION_DELAY_SECONDS}, capping to maximum")
        delay = MAX_NOTIFICATION_DELAY_SECONDS
    
    # Remove delay from payload before sending (it's not part of APNs payload)
    payload_without_delay = {k: v for k, v in payload.items() if k != "delay"}
    
    try:
        # Use asyncio.sleep with validated delay
        await asyncio.sleep(delay)
        
        if push_service is None:
            logger.error("Push notification service is not configured - cannot send delayed notification")
            return
        
        await push_service.send_notification(device_token, payload_without_delay)
    except OverflowError as e:
        logger.error(f"Overflow error with delay {delay} seconds: {e}. This should not happen after validation.")
    except Exception as e:
        logger.error(f"Failed to send delayed notification to {device_token[:20]}...: {e}")
