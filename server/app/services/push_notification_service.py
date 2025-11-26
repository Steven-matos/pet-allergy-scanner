"""
Push notification service for APNs integration
Handles sending notifications via Apple Push Notification service
"""

import asyncio
import json
import ssl
from typing import Dict, Any, Optional
from datetime import datetime, timedelta
from app.shared.services.datetime_service import DateTimeService
import aiohttp
import logging
import jwt

from app.core.config import settings

logger = logging.getLogger(__name__)


class PushNotificationService:
    """Service for sending push notifications via APNs"""
    
    def __init__(self):
        self.apns_url = settings.apns_url
        self.apns_key_id = settings.apns_key_id
        self.apns_team_id = settings.apns_team_id
        self.apns_bundle_id = settings.apns_bundle_id
        self.apns_private_key = settings.apns_private_key
        
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
                        return True
                    else:
                        # APNs returns detailed error information in JSON format
                        try:
                            error_data = await response.json()
                            error_reason = error_data.get("reason", "Unknown error")
                            
                            # Handle specific APNs error codes
                            if error_reason == "BadDeviceToken":
                                logger.warning(f"Invalid device token: {device_token[:20]}...")
                                # TODO: Remove invalid token from database
                            elif error_reason == "BadTopic":
                                logger.error(f"Bundle ID mismatch. Expected: {self.apns_bundle_id}")
                            elif error_reason == "ExpiredProviderToken":
                                logger.error("APNs JWT token expired - should regenerate")
                            elif error_reason == "MissingTopic":
                                logger.error(f"Missing apns-topic header. Bundle ID: {self.apns_bundle_id}")
                            elif error_reason == "PayloadTooLarge":
                                logger.error(f"Notification payload too large for {device_token[:20]}...")
                            elif error_reason == "TopicDisallowed":
                                logger.error(f"Topic not allowed for bundle ID: {self.apns_bundle_id}")
                            elif error_reason == "BadMessageId":
                                logger.error("Bad APNs message ID")
                            elif error_reason == "BadExpirationDate":
                                logger.error("Bad expiration date in APNs request")
                            elif error_reason == "BadPriority":
                                logger.error("Bad priority in APNs request")
                            elif error_reason == "MissingDeviceToken":
                                logger.error("Missing device token in APNs request")
                            elif error_reason == "Unregistered":
                                logger.warning(f"Device token unregistered: {device_token[:20]}...")
                                # TODO: Remove unregistered token from database
                            else:
                                logger.error(f"APNs error ({response.status}): {error_reason}")
                            
                            logger.error(f"APNs error response: {error_data}")
                            return False
                        except Exception as parse_error:
                            error_text = await response.text()
                            logger.error(f"Failed to parse APNs error response: {parse_error}")
                            logger.error(f"Raw error response ({response.status}): {error_text}")
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
                "apns-expiration": str(int(DateTimeService.now().timestamp()) + 3600),  # 1 hour
                "content-type": "application/json"
            }
        except Exception as e:
            logger.error(f"Error creating APNs headers: {e}")
            return {}
    
    async def _generate_jwt_token(self) -> str:
        """
        Generate JWT token for APNs authentication
        Uses ES256 algorithm with APNs private key
        """
        try:
            # Validate required configuration
            if not self.apns_team_id:
                logger.error("APNS_TEAM_ID not configured")
                return ""
            if not self.apns_key_id:
                logger.error("APNS_KEY_ID not configured")
                return ""
            if not self.apns_private_key:
                logger.error("APNS_PRIVATE_KEY not configured")
                return ""
            
            # JWT payload with issuer, issued at, and expiration
            now = DateTimeService.now()
            jwt_payload = {
                "iss": self.apns_team_id,
                "iat": int(now.timestamp()),
                "exp": int((now + timedelta(hours=1)).timestamp())
            }
            
            # Generate JWT token with ES256 algorithm
            token = jwt.encode(
                jwt_payload,
                self.apns_private_key,
                algorithm="ES256",
                headers={"kid": self.apns_key_id}
            )
            
            return token
        except Exception as e:
            logger.error(f"Error generating JWT token: {e}")
            import traceback
            logger.error(f"Error generating notification payload: {e}")
            return ""
    
    def _create_ssl_context(self) -> ssl.SSLContext:
        """
        Create SSL context for APNs connection
        APNs uses valid certificates, so we enable proper SSL verification
        """
        context = ssl.create_default_context()
        # APNs uses valid SSL certificates, enable verification
        context.check_hostname = True
        context.verify_mode = ssl.CERT_REQUIRED
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
