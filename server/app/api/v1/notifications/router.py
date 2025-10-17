"""
Push notification router for handling APNs integration
Handles device token registration, notification sending, and management
"""

from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from fastapi.security import HTTPBearer
from typing import Dict, Any, Optional
import json
import asyncio
from datetime import datetime, timedelta
from pydantic import BaseModel

from app.database import get_db
from app.models.user import User
from app.core.security.jwt_handler import get_current_user
from app.utils.logging_config import get_logger
from app.services.push_notification_service import PushNotificationService

logger = get_logger(__name__)

router = APIRouter(prefix="/notifications", tags=["notifications"])
security = HTTPBearer()

# Initialize push notification service
push_service = PushNotificationService()


class DeviceTokenRequest(BaseModel):
    """Request model for device token registration"""
    device_token: str


@router.post("/register-device")
async def register_device_token(
    request: DeviceTokenRequest,
    current_user: User = Depends(get_current_user),
    supabase = Depends(get_db)
):
    """
    Register device token for push notifications
    
    Args:
        request: DeviceTokenRequest containing device_token
        current_user: Current authenticated user
        supabase: Supabase client
        
    Returns:
        Success message
    """
    try:
        # Extract device token from request
        device_token = request.device_token
        
        # Update user's device token
        response = supabase.table("users").update({
            "device_token": device_token,
            "updated_at": datetime.utcnow().isoformat()
        }).eq("id", current_user.id).execute()
        
        if not response.data:
            raise HTTPException(status_code=500, detail="Failed to update device token")
        
        return {"message": "Device token registered successfully"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to register device token: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to register device token: {str(e)}")


@router.post("/send")
async def send_push_notification(
    device_token: str,
    payload: Dict[str, Any],
    current_user: User = Depends(get_current_user),
    background_tasks: BackgroundTasks = None
):
    """
    Send push notification to device
    
    Args:
        device_token: Target device token
        payload: Notification payload
        current_user: Current authenticated user
        background_tasks: Background tasks handler
        
    Returns:
        Success message
    """
    try:
        # Add delay if specified in payload
        delay = payload.get("delay", 0)
        
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
            await push_service.send_notification(device_token, payload)
            return {"message": "Notification sent successfully"}
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to send notification: {str(e)}")


@router.post("/cancel-all")
async def cancel_all_notifications(
    current_user: User = Depends(get_current_user),
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
        # Cancel all scheduled notifications for this user
        await push_service.cancel_user_notifications(current_user.id)
        
        return {"message": "All notifications cancelled successfully"}
    except Exception as e:
        logger.error(f"Failed to cancel notifications: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to cancel notifications: {str(e)}")


@router.post("/schedule-engagement")
async def schedule_engagement_notifications(
    current_user: User = Depends(get_current_user),
    background_tasks: BackgroundTasks = None
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
    current_user: User = Depends(get_current_user),
    background_tasks: BackgroundTasks = None
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
        delay: Delay in seconds
    """
    await asyncio.sleep(delay)
    try:
        await push_service.send_notification(device_token, payload)
    except Exception as e:
        logger.error(f"Failed to send delayed notification: {e}")
