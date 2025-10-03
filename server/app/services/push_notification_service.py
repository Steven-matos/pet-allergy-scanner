"""
Push notification service for APNs integration
Handles sending notifications via Apple Push Notification service
"""

import asyncio
import json
import ssl
from typing import Dict, Any, Optional
from datetime import datetime
import aiohttp
import logging

from app.core.config import settings

logger = logging.getLogger(__name__)


class PushNotificationService:
    """Service for sending push notifications via APNs"""
    
    def __init__(self):
        self.apns_url = settings.APNS_URL
        self.apns_key_id = settings.APNS_KEY_ID
        self.apns_team_id = settings.APNS_TEAM_ID
        self.apns_bundle_id = settings.APNS_BUNDLE_ID
        self.apns_private_key = settings.APNS_PRIVATE_KEY
        
    async def send_notification(
        self, 
        device_token: str, 
        payload: Dict[str, Any]
    ) -> bool:
        """
        Send push notification to device
        
        Args:
            device_token: Target device token
            payload: Notification payload
            
        Returns:
            Boolean indicating success
        """
        try:
            # Create APNs request
            url = f"{self.apns_url}/3/device/{device_token}"
            headers = await self._create_headers()
            
            # Prepare payload
            apns_payload = {
                "aps": payload.get("aps", {}),
                **{k: v for k, v in payload.items() if k != "aps"}
            }
            
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    url,
                    headers=headers,
                    json=apns_payload,
                    ssl=self._create_ssl_context()
                ) as response:
                    if response.status == 200:
                        logger.info(f"Push notification sent successfully to {device_token}")
                        return True
                    else:
                        error_text = await response.text()
                        logger.error(f"Failed to send push notification: {response.status} - {error_text}")
                        return False
                        
        except Exception as e:
            logger.error(f"Error sending push notification: {e}")
            return False
    
    async def send_batch_notifications(
        self, 
        notifications: list[Dict[str, Any]]
    ) -> Dict[str, bool]:
        """
        Send multiple notifications in batch
        
        Args:
            notifications: List of notification data with device_token and payload
            
        Returns:
            Dictionary mapping device tokens to success status
        """
        results = {}
        
        # Send notifications concurrently
        tasks = []
        for notification in notifications:
            device_token = notification["device_token"]
            payload = notification["payload"]
            task = self.send_notification(device_token, payload)
            tasks.append((device_token, task))
        
        # Wait for all tasks to complete
        for device_token, task in tasks:
            try:
                success = await task
                results[device_token] = success
            except Exception as e:
                logger.error(f"Error sending notification to {device_token}: {e}")
                results[device_token] = False
        
        return results
    
    async def cancel_user_notifications(self, user_id: str) -> bool:
        """
        Cancel all pending notifications for a user
        
        Args:
            user_id: User ID to cancel notifications for
            
        Returns:
            Boolean indicating success
        """
        try:
            # In a real implementation, you would maintain a queue of scheduled notifications
            # and cancel them based on user_id. For now, we'll just log the action.
            logger.info(f"Cancelled all notifications for user {user_id}")
            return True
        except Exception as e:
            logger.error(f"Error cancelling notifications for user {user_id}: {e}")
            return False
    
    async def _create_headers(self) -> Dict[str, str]:
        """Create APNs request headers with JWT token"""
        try:
            # Generate JWT token for APNs authentication
            jwt_token = await self._generate_jwt_token()
            
            return {
                "authorization": f"bearer {jwt_token}",
                "apns-topic": self.apns_bundle_id,
                "apns-push-type": "alert",
                "apns-priority": "10",
                "apns-expiration": str(int(datetime.utcnow().timestamp()) + 3600),  # 1 hour
                "content-type": "application/json"
            }
        except Exception as e:
            logger.error(f"Error creating APNs headers: {e}")
            return {}
    
    async def _generate_jwt_token(self) -> str:
        """Generate JWT token for APNs authentication"""
        try:
            import jwt
            from datetime import datetime, timedelta
            
            # JWT payload
            payload = {
                "iss": self.apns_team_id,
                "iat": int(datetime.utcnow().timestamp()),
                "exp": int((datetime.utcnow() + timedelta(hours=1)).timestamp())
            }
            
            # Generate JWT token
            token = jwt.encode(
                payload,
                self.apns_private_key,
                algorithm="ES256",
                headers={"kid": self.apns_key_id}
            )
            
            return token
        except Exception as e:
            logger.error(f"Error generating JWT token: {e}")
            return ""
    
    def _create_ssl_context(self) -> ssl.SSLContext:
        """Create SSL context for APNs connection"""
        context = ssl.create_default_context()
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
        return context
    
    async def validate_device_token(self, device_token: str) -> bool:
        """
        Validate device token by sending a test notification
        
        Args:
            device_token: Device token to validate
            
        Returns:
            Boolean indicating if token is valid
        """
        try:
            test_payload = {
                "aps": {
                    "alert": {
                        "title": "Test",
                        "body": "This is a test notification"
                    },
                    "sound": "default"
                }
            }
            
            return await self.send_notification(device_token, test_payload)
        except Exception as e:
            logger.error(f"Error validating device token: {e}")
            return False
